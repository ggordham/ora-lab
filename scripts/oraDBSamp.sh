#!/bin/bash

# oraDBSamp.sh

# install the Oracle database sample schemas
# Note: as of Mar 2023 this script is broken as the sample schema build
#  process has changed.

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# Default config information if not passed on command line
CONF_FILE="${SCRIPTDIR}"/server.conf
DEF_CONF_FILE="${SCRIPTDIR}"/ora_inst_files.conf

# retun command line help information
function help_oraDBSamp {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   Install and setup Oracle Rest Data Services " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
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
    my_opts=$(getopt -o hv --long debug,test,version,stgdir:,datatbs:,temptbs -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraDBCA                          #  help
                     exit 1;;
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
    if [ "${stg_dir}" == "__UNDEFINED__" ]; then stg_dir=$( cfgGet "$DEF_CONF_FILE" stg_dir ); fi
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
    if [ -z "${samp_schema_source:-}" ]; then samp_schema_source=$( cfgGet "$CONF_FILE" srvr_samp_schema_source ); fi
    if [ "${samp_schema_source}" == "__UNDEFINED__" ]; then samp_schema_source=$( cfgGet "$DEF_CONF_FILE" samp_schema_source ); fi
    if [ "${samp_schema_source}" == "file" ]; then samp_schema_file=$( cfgGet "$DEF_CONF_FILE" samp_schema_file );
        src_base=$( cfgGet "$DEF_CONF_FILE" src_base );
    elif [ "${samp_schema_source}" == "url" ]; then samp_schema_url=$( cfgGet "$DEF_CONF_FILE" samp_schema_url ); fi

    # Check that we have a sample schema source
    if [ "${samp_schema_source}" == "file" ] && [ "${samp_schema_file}" == "__UNDEFINED__" ]; then 
        logMesg 1 "could not load samp_schema_file from config file: $DEF_CONF_FILE" E "NONE" 
        exit 1
    elif [ "${samp_schema_source}" == "url" ] && [ "${samp_schema_url}" == "__UNDEFINED__" ]; then 
        logMesg 1 "could not load samp_schema_url from config file: $DEF_CONF_FILE" E "NONE" 
        exit 1
    fi 
    if [ "${samp_schema_source}" == "file" ] && [ ! -r "${src_base}/${samp_schema_file}" ]; then 
        logMesg 1 "could not read sample schema file at: ${src_base}/${samp_schema_file}" E "NONE" 
        exit 1
    fi

    # decide on what SID or PDB to use for install
    ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid )
    ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb )

    if [ "${ora_db_pdb}" == "__UNDEFINED__" ] || [ -z "${ora_db_pdb:-}" ] ; then
        logMesg 0 "No PDB defined, assuming database is a NON-CDB: $ora_db_sid" I "NONE"
        db_name="${ora_db_sid}"
    else
        logMesg 0 "PDB defined, installing into: $ora_db_pdb" I "NONE"
        db_name="${ora_db_pdb}"
    fi

    # get server specific settings for Listener
    ora_lsnr_port=$( cfgGet "$CONF_FILE" srvr_ora_lsnr_port )
    if [ "${ora_lsnr_port}" == "__UNDEFINED__" ]; then ora_lsnr_port=$( cfgGet "$DEF_CONF_FILE" ora_lsnr_port ); fi
    connect_string="localhost:${ora_lsnr_port}/${db_name}"

    # setup Oracle environment
    logMesg 0 "setting Oracle enviorment for home: $ora_db_sid" I "NONE"
    export ORACLE_SID="${ora_db_sid}"
    export ORAENV_ASK=NO
    source /usr/local/bin/oraenv -s

    # look for tablespaces to use for sample schema install
    if [ -z "${samp_tablespace:-}" ]; then samp_tablespace=$( cfgGet "$CONF_FILE" srvr_samp_tablespace ); fi
    if [ "${samp_tablespace}" == "__UNDEFINED__" ]; then samp_tablespace=$( cfgGet "$DEF_CONF_FILE" samp_tablespace ); fi
    if [ -z "${samp_temp:-}" ]; then samp_temp=$( cfgGet "$CONF_FILE" srvr_samp_temp ); fi
    if [ "${samp_temp}" == "__UNDEFINED__" ]; then samp_temp=$( cfgGet "$DEF_CONF_FILE" samp_temp ); fi

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
        logMesg 0 "unzipping the sample schema scripts" I "NONE"
        /usr/bin/unzip "${src_base}/${samp_schema_file}" -d "${tgt_dir}"
    elif [  "${samp_schema_source}" == "file" ]; then
        logMesg 0 "downloading the sample schema scripts" I "NONE"
        /usr/bin/curl -L "${samp_schema_url}/tarball/main" | tar xz --strip=1 -C "${tgt_dir}" 
    else
        logMesg 1 "unsuported sample schema file source: ${samp_schema_source}" E "NONE" 
        exit 1
    fi

    # update path in scripts to target directory
    /usr/bin/find "${tgt_dir}" -type f \( -name "*.sql" -o -name "*.dat" \) -exec sed -i "s#__SUB__CWD__#${tgt_dir}#g" {} \;

    cd "${tgt_dir}" || echo "Error, could not find directory: ${tgt_dir}"
    
    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect system/${system_password}@${connect_string}

WHENEVER sqlerror CONTINUE;

@mksample ${system_password} ${sys_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_tablespace} ${samp_temp} ${tgt_dir}/log ${connect_string}

!EOF
    return_code=$?
    # lets see if there was an error, and clean up so we can re-run
    if (( return_code > 0 )); then 
        echo "sample schema SQLPLUS return code: $return_code"
        /usr/bin/rm -rf "${tgt_dir}"
        exit ${return_code}
    fi
    
    # install the customer order schema
    cd "${tgt_dir}/customer_orders" || echo "Error, could not find directory: ${tgt_dir}/customer_orders"

    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect system/${system_password}@${connect_string}

WHENEVER sqlerror CONTINUE;
@co_main ${samp_password} ${connect_string} ${samp_tablespace} ${samp_temp}

!EOF
    return_code=$?

    echo "customer orders SQLPLUS return code: $return_code"
    exit ${return_code}
else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

# END 
