#!/bin/bash 
# oraLsnr.sh - Create Oracle database Listener with NETCA

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# Default config information if not passed on command line
CONF_FILE="${SCRIPTDIR}"/server.conf
DEF_CONF_FILE="${SCRIPTDIR}"/ora_inst_files.conf

# retun command line help information
function help_oraTNS {
  echo >&2
  echo "$SCRIPTNAME                                     " >&2
  echo "   used to add a TNS entry to TNS file in Oracle Home" >&2
  echo "   version: $SCRIPTVER                          " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
  echo "--dbservice [DB Service] REQUIRED*****          " >&2
  echo "--orahome   [Oracle home]                       " >&2
  echo "--port      [TCP Port]                          " >&2
  echo "--tnsfile   [TNS File]                          " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraTNS {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,dbservice:,orahome:,port:,tnsfile: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraTNS                          #  help
                     exit 1;;
          "--dbservice") ora_db_sid="$2"
                     shift 2;;
          "--orahome") ora_home="$2"
                     shift 2;;
          "--port") ora_lsnr_port="$2"
                     shift 2;;
           "--tnsfile") tns_file="$2"
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

  # check for required command line options
  if [ -z "${ora_db_sid:-}" ]; then
     echo "ERROR! Required option --dbservice not provided"
     (( badopt=1 ))
  fi
  return $badopt

}

############################################################################################
# start here

OPTIONS=$@

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

if checkopt_oraTNS "$OPTIONS" ; then

    logMesg 0 "$SCRIPTNAME start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if a ORACLE_HOME and other settings, otherwise lookup default setting
    if [ -z "${ora_home:-}" ]; then ora_home=$( cfgGet "$CONF_FILE" srvr_ora_home ); fi
    if [ -z "${ora_lsnr_port:-}" ]; then ora_lsnr_port=$( cfgGet "$CONF_FILE" srvr_ora_lsnr_port ); fi
    if [ "${ora_lsnr_port}" == "__UNDEFINED__" ]; then ora_lsnr_port=$( cfgGet "$DEF_CONF_FILE" ora_lsnr_port ); fi

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_HOME: $ora_home" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_lsnr_port: $ora_lsnr_port" I "NONE" ; fi
 
    # Setup Oracle environment
    ORACLE_HOME="$ora_home"
    ORACLE_BASE=$( "${ORACLE_HOME}/bin/orabase" )
    LD_LIBRARY_PATH=${ORACLE_HOME}/lib
    export ORACLE_HOME ORACLE_BASE LD_LIBRARY_PATH

    # Identify the proper TNS file
    if [ -z "${tns_file:-}" ]; then
        # check for readonly Oracle Home
        if [ -x "$ORACLE_HOME"/bin/orabasehome ]; then tns_base=$( "$ORACLE_HOME"/bin/orabasehome )
        else tns_base="$ORACLE_HOME"; fi
        tns_file="${tns_base}/network/admin/tnsnames.ora"
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "tns_base: $tns_base" I "NONE" ; fi
    fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "tns_file: $tns_file" I "NONE" ; fi

    # create TNS entires
    if [ "$TEST" == "TRUE" ]; then
        logMesg 0 "Test mode not running: mk_oratns ${tns_file} ${ora_db_sid} $( /bin/hostname -f ) ${ora_lsnr_port}" I "NONE"
    else
        logMesg 0 "Updating TNS file: $tns_file" I "NONE"
        [ ! -f "${tns_file}" ] && /usr/bin/touch "${tns_file}"
        mk_oratns "${tns_file}" "${ora_db_sid}" "$( /bin/hostname -f )" "${ora_lsnr_port}"
        return_code=$?
    fi

    if (( return_code > 0 )); then logMesg 1 "Error creating TNS entry!" E "NONE"
    else logMesg 0 "TNS entry for $ora_db_sid created." I "NONE"; fi
    exit $return_code
else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

