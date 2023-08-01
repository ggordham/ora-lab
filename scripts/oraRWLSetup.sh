#!/bin/bash
#
# oraRWLSetup.sh - sets up the schema and data for
# the RWP*Load Simulator
#   More information at: https://github.com/oracle/rwloadsim

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
# shellcheck disable=SC1090
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraRWLSetup {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to run RWP*Load Simulator OLTP .       " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--dir     [Install direcotry]                   " >&2
  echo "--outdir  [RWL output directory]                " >&2
  echo "--proj    [RWL project name]                    " >&2
  echo "--dbsid   [DB SID]                              " >&2
  echo "--dbpdb   [DB pdb name for CDB only]            " >&2
  echo "--datadir [DB data directory]                   " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
  echo "                                                " >&2
  echo " Note: outdir is also location of RWL project   " >&2
}

#check command line options
function checkopt_oraRWLSetup {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,dir:,outdir:,proj:,dbsid:,dbpdb:,datadir: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraRWLSetup                      #  help
                     exit 1;;
          "--dir") rwl_dir="$2"
                     shift 2;;
          "--outdir") rwl_outdir="$2"
                     shift 2;;
          "--proj") rwl_proj="$2"
                     shift 2;;
          "--dbsid") ora_db_sid="$2"
                     shift 2;;
          "--dbpdb") ora_db_pdb="$2"
                     shift 2;;
           "--datadir") ora_db_data="$2"
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

# shellcheck disable=SC2124
OPTIONS=$@

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

if checkopt_oraRWLSetup "$OPTIONS" ; then

    # check if a oracle_db_sid and other settings, otherwise lookup default setting
    if [ -z "${ora_db_sid:-}" ]; then ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid ); fi
    if [ -z "${ora_db_pdb:-}" ]; then ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb ); fi
    if [ -z "${rwl_dir:-}" ]; then rwl_dir=$( cfgGet "$CONF_FILE" rwl_dir ); fi
    if [ -z "${rwl_outdir:-}" ]; then rwl_outdir=$( cfgGet "$CONF_FILE" rwl_outdir ); fi
    if [ -z "${rwl_proj:-}" ]; then rwl_proj=$( cfgGet "$CONF_FILE" rwl_proj ); fi
    if [ -z "${ora_db_data:-}" ]; then ora_db_data=$( cfgGet "$CONF_FILE" ora_db_data ); fi

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_sid: $ora_db_sid" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_pdb: $ora_db_pdb" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_proj: $rwl_proj" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_dir: $rwl_dir" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_outdir: $rwl_outdir" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_data: $ora_db_data" I "NONE" ; fi
    
    # Lookup password for database
    secret_name="db_all_${ora_db_sid}"
    db_password=$( getSecret "${secret_name}" )
    if [ "$db_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for DB, secret: $secret_name" E "NONE" 
        exit 1
    fi

    # Lookup password for RWL schemas
    secret_name="db_rwl_${ora_db_sid}"
    rwl_password=$( getSecret "${secret_name}" )
    if [ "$rwl_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for RWL schemas, secret: $secret_name" E "NONE" 
        exit 1
    fi

    # Source the RWL project environment
    rwl_env_file="${rwl_outdir}/workdir/${rwl_proj}/${rwl_proj}.env"
    if [ -f "${rwl_env_file}" ]; then
        # shellcheck disable=SC1090
        source "${rwl_env_file}"
    else
        logMesg 1 "ERROR RWL environment file not found at: $rwl_env_file" E "NONE" 
        logMesg 1 "  Verify that oraRWLInst.sh has been run correctly." E "NONE" 
        exit 1
    fi

    # modify the required scripts for running
    temp_dir="${rwl_dir}/temp"
    [ ! -d "${temp_dir}" ] && mkdir "${temp_dir}"
    /usr/bin/cp "${rwl_dir}/admin/rwlschema.sql" "${temp_dir}"
    /usr/bin/sed -i "s/{password}/${rwl_password}/" "${temp_dir}"/rwlschema.sql

    # Setup the Oracle environment
    export ORACLE_SID=${ora_db_sid}
    export ORAENV_ASK=NO
    # shellcheck disable=SC1091
    source /usr/local/bin/oraenv -s

    # Adjust based on if PDB is configured or not
    if [ "${ora_db_pdb}" == "__UNDEFINED__" ] || [ -z "${ora_db_pdb:-}" ] ; then
        logMesg 0 "No PDB defined, assuming database is a NON-CDB: $ora_db_sid" I "NONE"
        rwl_file="${ora_db_data}/${ora_db_sid}/data01.dbf" 
    else
        export ORACLE_PDB_SID=${ora_db_pdb}
        rwl_file="${ora_db_data}/${ora_db_sid^^}/${ora_db_pdb}/data01.dbf" 
    fi

    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF > "${temp_dir}/rwlschema.log" 2>&1

connect / as sysdba
@${temp_dir}/rwlschema.sql

CREATE TABLESPACE DATA DATAFILE '${rwl_file}' SIZE 6G;

connect rwloadsim/${rwl_password}@${ora_db_pdb}

@${rwl_dir}/admin/rwloadsim.sql
@${rwl_dir}/admin/rwlviews.sql
!EOF

    # verify the following items:
    #  directory structure
    oltpverify -d > "${temp_dir}/oltpverify_dir.log"
    if grep -qE "fixed|writable" "${temp_dir}/oltpverify_dir.log"; then
        echo "ERROR - directory sturcture for OLTP could not be verified!"
        echo "ERROR - check log file: ${temp_dir}/oltpverify_dir.log"
        exit 1
    fi

    # verify test OLTP schemas and DB connections
    # example response where everything is good
    # repository:ok systemdb:ok cruserdb:ok runuser:ok
    oltpverify -a > "${temp_dir}/oltpverify_db.log"
    if grep -q fail "${temp_dir}/oltpverify_db.log"; then
        echo "ERROR - issue with database connection or setup"
        echo "ERROR - check log file: ${temp_dir}/oltpverify_db.log"
        tail -1 "${temp_dir}/oltpverify_db.log"
    else  
        echo "INFO - DB test status: "
        tail -1 "${temp_dir}/oltpverify_db.log"
    fi


    #   system access to test database
    #   repository access for RWL
    # look for the word fail:
    #   repository:fail 
    # oltpverify -s
    # oltpverify -r

    # Create the OLTP schema in the test database
    #   if you have issues you can drop the OLT test schemas
    #   oltpdrop
    oltpcreate > "${temp_dir}/oltpcreate.log"
    if grep -i error "${temp_dir}/oltpcreate.log"; then
        echo "ERROR - creating OLTP schemas and loading data"
        echo "ERROR - check log file: ${temp_dir}/oltpcreate.log"
        echo "ERROR - oltpdrop is being run to prepare for re-run"
        oltpdrop > "${temp_dir}/oltpdrop.log"
        exit 1
    else
        echo "INFO - no errors detected in OLTP load"
    fi

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

