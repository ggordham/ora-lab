#!/bin/bash 
# oraDBCA.sh - Create Oracle database with DBCA

# Internal settings
export SCRIPTDIR 
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraDBCA {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to run DBCA to create Oracle database  " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--datadir [DB data directory]                   " >&2
  echo "--dbsid   [DB SID]                              " >&2
  echo "--dbtype  [DB type CDB|NCDB]                    " >&2
  echo "--dbpdb   [DB pdb name for CDB only]            " >&2
  echo "--insecure do not remove passwords from response file" >&2
  echo "--dbcatemp [DBCA Template response file]        " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraDBCA {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,insecure,datadir:,dbsid:,dbtype:,dbpdb:,orahome:,dbcatemp: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraDBCA                          #  help
                     exit 1;;
          "--datadir") ora_db_data="$2"
                     shift 2;;
          "--dbsid") ora_db_sid="$2"
                     shift 2;;
          "--dbtype") ora_db_type="$2"
                     shift 2;;
          "--dbpdb") ora_db_pdb="$2"
                     shift 2;;
          "--orahome") ora_home="$2"
                     shift 2;;
          "--dbcatemp") dbca_temp="$2"
                     shift 2;;
           "--insecure") INSECURE=TRUE                           # test mode
                     shift ;;
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

OPTIONS=$@

# manual variables used in DBCA response file to prevent errors not seen in this script
#   these do not come from configuration file for now
export container_flag

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

if checkopt_oraDBCA "$OPTIONS" ; then

    logMesg 0 "$SCRIPTNAME start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if a ORACLE_HOME and other settings, otherwise lookup default setting
    if [ -z "${ora_home:-}" ]; then ora_home=$( cfgGet "$CONF_FILE" srvr_ora_home ); fi
    if [ -z "${ora_db_sid:-}" ]; then ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid ); fi
    if [ -z "${ora_db_type:-}" ]; then ora_db_type=$( cfgGet "$CONF_FILE" ora_db_type ); fi
    if [ -z "${ora_db_pdb:-}" ]; then ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb ); fi
    if [ -z "${ora_db_data:-}" ]; then ora_db_data=$( cfgGet "$CONF_FILE" ora_db_data ); fi
    if [ -z "${ora_db_mem:-}" ]; then ora_db_mem=$( cfgGet "$CONF_FILE" ora_db_mem ); fi

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_HOME: $ora_home" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_sid: $ora_db_sid" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_type: $ora_db_type" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_pdb: $ora_db_pdb" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_data: $ora_db_data" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_mem: $ora_db_mem" I "NONE" ; fi

    # Setup Oracle environment
    export ORACLE_HOME="$ora_home"
    ORACLE_BASE=$( "${ORACLE_HOME}/bin/orabase" )
    LD_LIBRARY_PATH=${ORACLE_HOME}/lib
    export ORACLE_HOME ORACLE_BASE LD_LIBRARY_PATH

    # run opatch to get db home version, only return the first line as that is probably the database product
    set -o pipefail; db_version=$( "${ORACLE_HOME}/OPatch/opatch" lsinventory | awk '/^Oracle Database/ {print $NF}' | head -1)
    return_code=$?
    if (( return_code > 0 )); then
        logMesg 1 "ORACLE_HOME failure getting version: $ORACLE_HOME" E "NONE" 
        exit 1
    fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "db_version: $db_version" I "NONE" ; fi

    # set the oracle version
    #  Note need to add code to map 11.1, 11.2, 12.1, 12.2 to 11g1, 11g2, 12c1, 12c2
    #    only works for 18, 19, 21, 23 right now
    ora_ver=${db_version%%.*}
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_ver: $ora_ver" I "NONE" ; fi

    # Lookup password for database
    secret_name="db_all_${ora_db_sid}"
    db_password=$( getSecret "${secret_name}" )
    if [ "$db_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for DB, secret: $secret_name" E "NONE" 
        exit 1
    fi

    # Genearte a DBCA response file
    if [ -z "${dbca_temp:-}" ]; then dbca_temp=$( cfgGet "$ORA_CONF_FILE" "${ora_ver}_dbca_temp" ); fi
    if [ "$dbca_temp" == "__UNDEFINED__" ]; then logMesg 1 "DBCA tempalte parameter not set: $dbca_temp" E "NONE"; exit 1; fi
    response_file="/tmp/dbca_${ora_db_sid}.rsp"
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "dbca_temp: $dbca_temp" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "response_file: $response_file" I "NONE" ; fi

    # check for container database
    case "${ora_db_type}" in
      "CDB")
        container_flag=true;;
      "NCDB")
        container_flag=false;;
      *)
        logMesg 1 "DB Type $ora_db_type not supported!" E "NONE"
        exit 1;
    esac

    # Configure DBCA variables
    db_variables="DB_UNIQUE_NAME=${ora_db_sid},ORACLE_BASE=${ORACLE_BASE},PDB_NAME=,DB_NAME=${ora_db_sid},ORACLE_HOME=${ORACLE_HOME},SID=${ora_db_sid}"

    # check the first part of the version number before the period
    case "${ora_ver}" in
        "23")
           echo "responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v23.0.0" >> "$response_file" 
           db_variables="ORACLE_BASE_HOME=$( "$ORACLE_HOME"/bin/orabasehome ),${db_variables}"
           ;;
        "21")
           echo "responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v21.0.0" >> "$response_file" 
           db_variables="ORACLE_BASE_HOME=$( "$ORACLE_HOME"/bin/orabasehome ),${db_variables}"
           ;;
        "19")
           echo "responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v19.0.0" >> "$response_file" 
           ;;
        *)
          echo "Oracle version $ora_ver not supported!"
          exit 1 ;;
    esac

    # build response file
    #  use little trick to process variables contained in response file
    if [ -f "${SCRIPTDIR}/${dbca_temp}" ]; then
        echo "# Response file generated by $SCRIPTNAME " > "${response_file}"
        echo "#   on date: $( /usr/bin/date )" >> "${response_file}"
        eval " echo \"$( cat "${SCRIPTDIR}/${dbca_temp}" )\"" >> "${response_file}"
    else
        logMesg 1 "Could not find DBCA template: ${SCRIPTDIR}/${dbca_temp}" E "NONE"
        exit 1;
    fi

    # run DBCA tool
    dbca_options=" -silent -ignorePreReqs -ignorePrereqFailure -createDatabase"
 
    if [ "$TEST" == "TRUE" ]; then 
        logMesg 0 "dbca command:  $ORACLE_HOME/bin/dbca $dbca_options -responseFile $response_file" I "NONE" 
    else
        sh -c "${ORACLE_HOME}/bin/dbca $dbca_options -responseFile $response_file"
        logMesg 0 "dbca completed with return code: $?" I "NONE"
    fi

    # Old options not included 
    # -enableArchive false
    # -archiveLogDest /opt/oracle/oradata/ORCLCDB/archive_logs -autoGeneratePasswords
    #

    # remove passwords from response file
    if [ -n "${INSECURE:-}" ] && [ "$INSECURE" == "TRUE" ]; then
        logMesg 0 "Insecure option, leaving passwords in response file." I "NONE"
    else
        /bin/sed -i "s/${db_password}/XXXXXXXX/g" "${response_file}"
    fi

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

