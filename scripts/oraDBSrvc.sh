#!/bin/bash

# oraDBSrvc.sh

# used to create, start, remove, and see status of Oracle DB service

# Internal settings
export SCRIPTDIR 
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# default settings
ALL_SCRIPT_MODES="add drop start stop status"
# retun command line help information
function help_oraDBSrvc {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   Create, start, remove or status DB service  " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
  echo "--dbsid   [DB SID]                              " >&2
  echo "--service [SERVICE NAME]                        " >&2
  echo "--mode    [ add | drop | start | stop | status ]" >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode                   " >&2
  echo "--version | -v Show the script version          " >&2
  echo >&2
  echo "Note: --status and --mode are exclusive of each " >&2
}

#check command line options
function checkopt_oraDBSrvc {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,dbsid:,mode:,service: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraDBSrvc                         #  help
                     exit 1;;
        "--service") ora_service="$2"
                     shift 2;;
          "--dbsid") ora_db_sid="$2"
                     shift 2;;
           "--mode") script_mode="$2"
                     script_mode="${script_mode^^}"   # change to uppercase
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

# add_service [service_name]
add_service() {
  
    local my_ora_service=$1

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "Test mode Not adding: $my_ora_service" I "NONE" ; return; fi
    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF 
SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect / as sysdba

BEGIN
 DBMS_SERVICE.CREATE_SERVICE( service_name => '${my_ora_service}' , network_name => '${my_ora_service}');
END;
/

COMMIT;

!EOF

}

# drop_service [service_name]
drop_service() {
  
    local my_ora_service=$1

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "Test mode Not deleting: $my_ora_service" I "NONE" ; return; fi
    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF 
SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect / as sysdba

BEGIN
 DBMS_SERVICE.DELETE_SERVICE( service_name => '${my_ora_service}');
END;
/

COMMIT;

!EOF

}

# start_service [service_name]
start_service () {

    local my_ora_service=$1

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "Test mode Not starting: $my_ora_service" I "NONE" ; return; fi
    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF 

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect / as sysdba

BEGIN
 DBMS_SERVICE.START_SERVICE( service_name => '${my_ora_service}');
END;
/

COMMIT;
!EOF
}

# stop_service [service_name]
stop_service () {

    local my_ora_service=$1

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "Test mode Not stopping: $my_ora_service" I "NONE" ; return; fi
    "${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF 

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect / as sysdba

BEGIN
 DBMS_SERVICE.STOP_SERVICE( service_name => '${my_ora_service}');
END;
/

COMMIT;
!EOF
}

# service_status
service_status () {

    "${ORACLE_HOME}"/bin/sqlplus -S /nolog << !EOF 

connect / as sysdba

set pagesize 100
column name format a20
column network_name format a20
select name, network_name, enabled from dba_services;
select name, network_name from v\$active_services;

!EOF

}

############################################################################################
# start here

# shellcheck disable=SC2124
OPTIONS=$@

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

if checkopt_oraDBSrvc "$OPTIONS" ; then

    # check that a script mode has been provided
    if [ -z "${script_mode:-}" ]; then
        echo "ERROR! no scirpt mode provided." >&2
        exit 1
    elif ! inList "${ALL_SCRIPT_MODES^^}" "${script_mode}" ; then
        echo "ERROR! invalid script mode, use one of: " >&2
        echo "   ${ALL_SCRIPT_MODES}" >&2
        exit 1
    fi

    # check if a oracle_db_sid and other settings, otherwise lookup default setting
    if [ -z "${ora_db_sid:-}" ]; then ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid ); fi

    # if we are doing status then set service to null, 
    #   otherwise check if paramter was passed
    if [ "$script_mode" == "STATUS" ]; then ora_service=""; 
    else
        if [ "${ora_service:-}" == "" ]; then
            logMesg 1 "ERROR - service name not provided with --service" E "NONE"
            exit 1
        fi
    fi

    # Test mode information
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_sid: $ora_db_sid" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "script_mode: $script_mode" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_service: $ora_service" I "NONE" ; fi

    # Setup the Oracle environment
    logMesg 0 "Setting Oracle environment for: $ora_db_sid" I "NONE"
    export ORACLE_SID=${ora_db_sid}
    export ORAENV_ASK=NO
    # shellcheck disable=SC1091
    source /usr/local/bin/oraenv -s

    # script modes
    case "${script_mode}" in
        "ADD")
            add_service "${ora_service}" ;;
        "DROP")
            drop_service "${ora_service}" ;;
        "START")
            start_service "${ora_service}" ;;
        "STOP")
            stop_service "${ora_service}" ;;
        "STATUS")
            service_status;;
        *)
            echo "  ERROR! invalid script mode: ${script_mode}" >&2
            exit 1
            ;;
    esac

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END
