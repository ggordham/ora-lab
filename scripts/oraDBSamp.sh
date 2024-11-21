#!/bin/bash

# oraDBSamp.sh

# install the Oracle database sample schemas
# Note: as of Mar 2023 this script is broken as the sample schema build
#  process has changed.

# Internal settings
export SCRIPTDIR 
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraDBSamp {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   Install and setup Oracle Rest Data Services " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
  echo "--db      [DB connect string]                   " >&2
  echo "--datatbs [Data Tablespace]                     " >&2
  echo "--temptbs [Temp Tablespace]                     " >&2
  echo "--stgdir  [Staging Directory]                   " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode                   " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraDBSamp {
    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,db:,stgdir:,datatbs:,temptbs -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraDBSamp                          #  help
                     exit 1;;
          "--db") db_name="$2"
                     shift 2;;
           "--stgdir") stg_dir="$2"
                     shift 2;;
          "--datatbs") samp_tablespace="$2"
                     shift 2;;
          "--temptbs") samp_temp="$2"
                     shift 2;;
          "--debug") DEBUG=TRUE                         # debug mode
                     set -x
                     shift ;;
           "--test") TEST=TRUE                           # test mode
                     shift ;;
           "--version"|"-v") echo "$SCRIPTNAME version: $SCRIPTVER" >&2
                     exit 0;;
                "--") shift; break;;                             # finish parsing
                  *) echo "ERROR! Bad command line option passed: $1"
                     (( badopt=1 ))
                     break ;;                                    # unknown flag
        esac
    done
  fi

  return $badopt

}

############################################################################################
# start here

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

OPTIONS=$@

if checkopt_oraDBSamp "$OPTIONS" ; then

    logMesg 0 "${SCRIPTNAME} start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # setup staging directory
    if [ -z "${stg_dir:-}" ]; then stg_dir=$( cfgGet "$CONF_FILE" srvr_stg_dir ); fi
    if [ "${stg_dir}" == "__UNDEFINED__" ]; then stg_dir=$( cfgGet "$ORA_CONF_FILE" stg_dir ); fi
    logMesg 0 "Making staging directory: $stg_dir" I "NONE"
    [ ! -d "${stg_dir}" ] && /usr/bin/mkdir -p "${stg_dir}"
    tgt_dir="${stg_dir}/examples"
    logMesg 0 "Making target directory: $tgt_dir" I "NONE"
    [ ! -d "${tgt_dir}" ] && /usr/bin/mkdir -p "${tgt_dir}"
    if [ ! -d "${tgt_dir}" ]; then 
        logMesg 1 "could not access stage directory: $tgt_dir" E "NONE" 
        exit 1
    fi 

    # look for sample schema source type
    if [ -z "${samp_schema_source:-}" ]; then samp_schema_source=$( cfgGetD "$CONF_FILE" srvr_samp_schema_source "$ORA_CONF_FILE" samp_schema_source ); fi
    if [ "${samp_schema_source}" == "file" ]; then samp_schema_file=$( cfgGet "$ORA_CONF_FILE" samp_schema_file );
        src_base=$( cfgGet "$ORA_CONF_FILE" src_base );
    elif [ "${samp_schema_source}" == "url" ]; then samp_schema_url=$( cfgGet "$ORA_CONF_FILE" samp_schema_url ); fi

    # Check that we have a sample schema source
    if [ "${samp_schema_source}" == "file" ] && [ "${samp_schema_file}" == "__UNDEFINED__" ]; then 
        logMesg 1 "could not load samp_schema_file from config file: $ORA_CONF_FILE" E "NONE" 
        exit 1
    elif [ "${samp_schema_source}" == "url" ] && [ "${samp_schema_url}" == "__UNDEFINED__" ]; then 
        logMesg 1 "could not load samp_schema_url from config file: $ORA_CONF_FILE" E "NONE" 
        exit 1
    fi 
    if [ "${samp_schema_source}" == "file" ] && [ ! -r "${src_base}/${samp_schema_file}" ]; then 
        logMesg 1 "could not read sample schema file at: ${src_base}/${samp_schema_file}" E "NONE" 
        exit 1
    fi

    # check if db_name was set on the comamnd line
    if [ -z "${db_name:-}" ]; then 
        # decide on what SID or PDB to use for install
        # check settings, otherwise lookup default setting
        if [ -z "${ora_db_sid:-}" ]; then ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid ); fi
        if [ -z "${ora_db_type:-}" ]; then ora_db_type=$( cfgGet "$CONF_FILE" ora_db_type ); fi
        if [ -z "${ora_db_pdb:-}" ]; then ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb ); fi
 
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_sid: $ora_db_sid" I "NONE" ; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_type: $ora_db_type" I "NONE" ; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_pdb: $ora_db_pdb" I "NONE" ; fi
  
        # check for container database
        case "${ora_db_type}" in
          "CDB")
            logMesg 0 "CDB defined using PDB: $ora_db_pdb" I "NONE"
            db_name="${ora_db_pdb}";;
          "NCDB")
            logMesg 0 "Non CDB defined using SID: $ora_db_sid" I "NONE"
            db_name="${ora_db_sid}";;
          *)
            logMesg 1 "DB Type $ora_db_type not supported!" E "NONE"
            exit 1;
        esac
    fi

    # get server specific settings for Listener
    ora_lsnr_port=$( cfgGet "$CONF_FILE" srvr_ora_lsnr_port )
    if [ "${ora_lsnr_port}" == "__UNDEFINED__" ]; then ora_lsnr_port=$( cfgGet "$ORA_CONF_FILE" ora_lsnr_port ); fi
    connect_string="localhost:${ora_lsnr_port}/${db_name}"

    # setup Oracle environment
    logMesg 0 "setting Oracle enviorment for home: $ora_db_sid" I "NONE"
    export ORACLE_SID="${ora_db_sid}"
    export ORAENV_ASK=NO
    source /usr/local/bin/oraenv -s

    # look for tablespaces to use for sample schema install
    if [ -z "${samp_tablespace:-}" ]; then samp_tablespace=$( cfgGetD "$CONF_FILE" srvr_samp_tablespace "$ORA_CONF_FILE" samp_tablespace ); fi
    if [ -z "${samp_temp:-}" ]; then samp_temp=$( cfgGetD "$CONF_FILE" srvr_samp_temp "$ORA_CONF_FILE" samp_temp ); fi

    # load passwords
    # Lookup password for database note we use the SID name for now
    secret_name="db_all_${ora_db_sid}"
    db_password=$( getSecret "${secret_name}" )
    if [ "$db_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for DB, secret: $secret_name" E "NONE" 
        exit 1
    fi
    sys_password="${db_password}"
    system_password="${db_password}"
    samp_password="${db_password}"

    # stage sample schema
    if [  "${samp_schema_source}" == "file" ]; then
        logMesg 0 "unzipping the sample schema scripts to: $tgt_dir" I "NONE"
        /usr/bin/unzip -oq "${src_base}/${samp_schema_file}" -d "${tgt_dir}"
    elif [  "${samp_schema_source}" == "file" ]; then
        logMesg 0 "downloading the sample schema scripts, loading to: $tgt_dir" I "NONE"
        /usr/bin/curl -L "${samp_schema_url}/tarball/main" | tar xz --strip=1 -C "${tgt_dir}" 
    else
        logMesg 1 "unsuported sample schema file source: ${samp_schema_source}" E "NONE" 
        exit 1
    fi

    # update path in scripts to target directory
    logMesg 0 "Updating scripts with installed path" I "NONE"
    cd "${tgt_dir}" || logMesg 1 "Error, could not change to directory: ${tgt_dir}" E "NONE"
    /usr/bin/find "${tgt_dir}" -type f \( -name "*.sql" -o -name "*.dat" \) -exec /bin/sed -i "s#__SUB__CWD__#${tgt_dir}#g" {} \;

    sql_log_dir="${tgt_dir}/log"
    [ ! -d "${sql_log_dir}" ] && /usr/bin/mkdir -p "${sql_log_dir}"
    sql_log_file="${sql_log_dir}/mksample-$( date +%Y%m%d-%H%M%S ).log"
    logMesg 0 "Check log file for errors: $sql_log_file" I "NONE"
    # Note log path being passed to script has to have trailing / or examples directory gets removed
    logMesg 0 "Running mksample xxxxx xxxxx xxxxx xxxxx xxxxx xxxxx xxxxx xxxxx xxxxx ${samp_tablespace} ${samp_temp} ${sql_log_dir}/ ${connect_string}"  I "NONE"
    
    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF > "${sql_log_file}" 2>&1

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect system/${system_password}@${connect_string}

WHENEVER sqlerror CONTINUE;

@mksample ${system_password} ${sys_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_tablespace} ${samp_temp} ${sql_log_dir}/ ${connect_string}

!EOF
    return_code=$?
    # lets see if there was an error, and clean up so we can re-run
    if (( return_code > 0 )); then 
        logMesg 0 "sample schema SQLPLUS return code: $return_code" I "NONE"
        /usr/bin/rm -rf "${tgt_dir}"
        exit ${return_code}
    fi
    
    # install the customer order schema
    cd "${tgt_dir}/customer_orders" || logMesg 1 "Error, could not find directory: ${tgt_dir}/customer_orders" E "NONE"
    sql_log_file="${sql_log_dir}/co_main-$( date +%Y%m%d-%H%M%S ).log"
    logMesg 0 "Check log file for errors: $sql_log_file" I "NONE"
    logMesg 0 " Note also check: $tgt_dir/customer_orders/co_install.log" I "NONE"
    logMesg 0 "Running co_main xxxxx ${connect_string} ${samp_tablespace} ${samp_temp}" I "NONE"

    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF > "${sql_log_file}" 2>&1

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect system/${system_password}@${connect_string}

WHENEVER sqlerror CONTINUE;
@co_main ${samp_password} ${connect_string} ${samp_tablespace} ${samp_temp}

!EOF
    return_code=$?

    logMesg 0 "customer orders SQLPLUS return code: $return_code" I "NONE"
    exit ${return_code}
else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

# END 
