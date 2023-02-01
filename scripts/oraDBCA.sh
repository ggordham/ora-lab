#!/bin/bash 
# oraDBCA.sh - Create Oracle database with DBCA

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# Default config information if not passed on command line
CONF_FILE="${SCRIPTDIR}"/server.conf

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
    my_opts=$(getopt -o hv --long debug,test,version,stgdir:,oraver:,orasubver:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraDBCA                          #  help
                     exit 1;;
          "--datadir") ora_data_dir="$2"
                     shift 2;;
          "--dbsid") ora_db_sid="$2"
                     shift 2;;
          "--dbtype") ora_db_type="$2"
                     shift 2;;
          "--dbpdb") ora_db_pdb="$2"
                     shift 2;;
          "--orahome") ora_home="$2"
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

OPTIONS=$@

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
    ORACLE_HOME="$ora_home"
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


    # Lookup password for database
    secret_name="db_all_${ora_db_sid}"
    db_password=$( getSecret "db_all_${ora_db_sid}" )
    if [ "$db_password" != "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for DB, secret: $secret_name" E "NONE" 
        exit 1
    fi

    # Genearte a DBCA response file
    response_file="/tmp/dbca_${ora_db_sid}.rsp"
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "response_file: $response_file" I "NONE" ; fi

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

    echo "# Response file generated by $SCRIPTNAME " > "${response_file}"
    echo "#   on date: $( date )" >> "${response_file}"
    # check the first part of the version number before the period
    case "${db_version%%.*}" in
        "23b")
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
          echo "Oracle version not supported!"
          exit 1 ;;
    esac

    cat << EOF >> "${response_file}"
#Database Name
gdbName=${ora_db_sid}
sid=${ora_db_sid}
# Server configuration
databaseConfigType=SI
RACOneNodeServiceName=
policyManaged=false
managementPolicy=AUTOMATIC
createServerPool=false
serverPoolName=
cardinality=
force=false
pqPoolName=
pqCardinality=
nodelist=
runCVUChecks=FALSE

createAsContainerDatabase=${container_flag}
numberOfPDBs=1
pdbName=${ora_db_pdb}
useLocalUndoForPDBs=true

templateName=General_Purpose.dbc

sysPassword=${db_password}
systemPassword=${db_password}
pdbAdminPassword=${db_password}
dbsnmpPassword=${db_password}

# Enterprise Manager Configuration (CENTRAL|DBEXPRESS|BOTH|NONE)
emConfiguration=NONE
emExpressPort=5500
omsHost=
omsPort=
emUser=
emPassword=

# Database Vault and Label Security configuration
olsConfiguration=false
dvConfiguration=false
dvUserName=
dvUserPassword=
dvAccountManagerName=
dvAccountManagerPassword=

# Database Configuration
# DB Storage
datafileJarLocation={ORACLE_HOME}/assistants/dbca/templates/
datafileDestination=${ora_db_data}/{DB_UNIQUE_NAME}/
recoveryAreaDestination=
recoveryAreaSize=54525952BYTES
storageType=FS
diskGroupName=
asmsnmpPassword=
recoveryGroupName=
useOMF=false
# DB Character set
characterSet=AL32UTF8
nationalCharacterSet=AL16UTF16
# DB init parameters
initParams=audit_trail=none,audit_sys_operations=false
# pga_aggregate_target=795MB,sga_target=2382MB


# DB memory parameters
automaticMemoryManagement=FALSE
totalMemory=${ora_db_mem}
databaseType=
memoryPercentage=

# DB Network configuraiton
listeners=
skipListenerRegistration=true
registerWithDirService=
dirServiceUserName=
dirServicePassword=
walletPassword=

# Misc other options
variablesFile=
variables=${db_variables}

# Note 21c + options:
# pdbOptions=SAMPLE_SCHEMA:false,IMEDIA:true,SPATIAL:true,CWMLITE:true,JSERVER:true,DV:true,OMS:true,ORACLE_TEXT:true
# dbOptions=SAMPLE_SCHEMA:false,IMEDIA:true,SPATIAL:true,CWMLITE:true,JSERVER:true,DV:true,OMS:true,ORACLE_TEXT:true
# enableArchive=false
EOF

    # run DBCA tool
    dbca_options=" -silent -ignorePreReqs -ignorePrereqFailure -createDatabase"
 
    if [ "$TEST" == "TRUE" ]; then 
        logMesg 0 "dbca command:  $ORACLE_HOME/bin/dbca $dbca_options -responseFile $response_file" I "NONE" 
    else
       sh -c "${ORACLE_HOME}/bin/dbca $dbca_options -responseFile $response_file"
    fi

    # Old options not included 
    # -enableArchive false
    # -archiveLogDest /opt/oracle/oradata/ORCLCDB/archive_logs -autoGeneratePasswords
    #

    # remove passwords from response file
    sed -i "s/${db_password}/XXXXXXXX/g" "${response_file}"

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

