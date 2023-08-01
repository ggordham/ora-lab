#!/bin/bash
#
# oraRWLRun.sh - run the OLTP RWP*Load Simulator
#   More information at: https://github.com/oracle/rwloadsim

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
# shellcheck disable=SC1090
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraRWLRun {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to run RWP*Load Simulator OLTP .       " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--dbsid   [DB SID to set ENV]                   " >&2
  echo "--proj    [RWL Project name]                    " >&2
  echo "--sec     [Length of test in seconds]           " >&2
  echo "--proc    [Number of processes to start]        " >&2
  echo "--outdir  [RWL output directory]                " >&2
  echo "--noverify  Skip RWL schema verification step   " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
  echo "                                                " >&2
  echo " Note: outdir is also location of RWL project   " >&2
}

#check command line options
function checkopt_oraRWLRun {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    NOVERIFY=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,noverify,dbsid:,proj:,sec:,proc:,outdir: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraRWLRun                        #  help
                     exit 1;;
          "--dbsid") ora_db_sid="$2"
                     shift 2;;
          "--proj") rwl_proj="$2"
                     shift 2;;
          "--sec") rwl_sec="$2"
                     shift 2;;
          "--proc") rwl_proc="$2"
                     shift 2;;
          "--outdir") rwl_outdir="$2"
                     shift 2;;
           "--noverify") NOVERIFY=TRUE                           # test mode
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

# shellcheck disable=SC2124
OPTIONS=$@

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

if checkopt_oraRWLRun "$OPTIONS" ; then

    logMesg 0 "$SCRIPTNAME start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if a oracle_db_sid and other settings, otherwise lookup default setting
    if [ -z "${ora_db_sid:-}" ]; then ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid ); fi
    if [ -z "${rwl_proj:-}" ]; then rwl_proj=$( cfgGet "$CONF_FILE" rwl_proj ); fi
    if [ -z "${rwl_sec:-}" ]; then rwl_sec=$( cfgGet "$CONF_FILE" rwl_sec ); fi
    if [ -z "${rwl_proc:-}" ]; then rwl_proc=$( cfgGet "$CONF_FILE" rwl_proc ); fi
    if [ -z "${rwl_outdir:-}" ]; then rwl_outdir=$( cfgGet "$CONF_FILE" rwl_outdir ); fi

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_sid: $ora_db_sid" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_proj: $rwl_proj" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_sec: $rwl_sec" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_proc: $rwl_proc" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_outdir: $rwl_outdir" I "NONE" ; fi

    # Setup the Oracle environment
    export ORACLE_SID=${ora_db_sid}
    export ORAENV_ASK=NO
    # shellcheck disable=SC1091
    source /usr/local/bin/oraenv

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

    rwl_bindir="$( dirname "$( /usr/bin/which oltpverify )" )"

    temp_dir=/home/oracle/temp
    log_file=${temp_dir}/oltprun-$( date +%Y%m%d-%H%M%S ).log

    # Run OLTP Verify to make sure everything is good
    if [ "$NOVERIFY" == "FALSE" ]; then 
      "${rwl_bindir}"/oltpverify -a
    fi

    echo "INFO - Starting OLTP run on DB ENV ${ora_db_sid} RWL Project ${rwl_proj}"
    echo "INFO - Log file at: ${log_file}"

    # check paramters
    rwl_cmd_opts="-b -r ${rwl_sec}"
    if [ "$rwl_proc" == "__UNDEFINED__" ] || [ -z "$rwl_proc" ]; then
        logMesg 0 "Number of processes not defined defaulting to 1" I "NONE"
    else
        rwl_cmd_opts="${rwl_cmd_opts} -n ${rwl_proc}"
    fi
    
    # Run the OLTP workload
    if [ "$TEST" == "TRUE" ]; then 
        logMesg 0 "TEST Mode RWL OLTP command: ${rwl_bindir}/oltpcore ${rwl_cmd_opts}" I "NONE"
    else
        "${rwl_bindir}"/oltpcore  ${rwl_cmd_opts} > "${log_file}"
        logMesg 0 "oltpcore complete with return code: $?"  I "NONE"
    fi

    logMesg 0 "Check log file at: ${log_file}" I "NONE"

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

