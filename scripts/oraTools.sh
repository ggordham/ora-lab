#!/bin/bash

# oraTools.sh - Install additional Oracle tools

# Internal settings, export empty variable that is set by library
export SCRIPTDIR
SCRIPTVER=1.1
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib
error_code=0

# default settings
tool_list="apex sqlcl autoup all"

# retun command line help information
function help_oraTools {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to stage Oracle DB software + patches  " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--oratool [apex | sqlcl | autoup | all]         " >&2
  echo "--orabase [Oracle base]                         " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--stgdir [Staging Directory]                    " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraTools {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,srcdir:,oratool:,stgdir:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraTools                          #  help
                     exit 1;;
          "--oratool") ora_tool="$2"
                     shift 2;;
          "--stgdir") stg_dir="$2"
                     shift 2;;
          "--orabase") ora_base="$2"
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

# function sqlcl_inst /u01/app/oracle/stage /u01/app/oracle
#
function sqlcl_inst () {

  local my_stgdir=$1
  local my_base=$2

  local my_sqlcl_url
  local my_file
  local my_return

  my_return=0

  # get SQLcl URL
  my_sqlcl_url=$( cfgGet "${ORA_CONF_FILE}" "sqlcl_latest" )

  # make staging location if it doesn't exist
  [ ! -d "${my_stgdir}" ] && /bin/mkdir -p "${my_stgdir}" 

  # download the file
  cd "${my_stgdir}"
  /bin/curl -O -L "${my_sqlcl_url}"
  cd -

  # get the filename for the install
  my_file="$( /bin/basename "${my_sqlcl_url}" )"

  # unzip the install
  if [ -f "${my_stgdir}/${my_file}" ]; then
      /bin/unzip -q "${my_stgdir}/${my_file}" -d "${my_base}"

      # add the alias for SQLcl to user profile
      echo "alias sql='${my_base}/sqlcl/bin/sql'" >> /home/oracle/.bashrc
  else
      logMesg 1 "Could not download the SQLcl install file: ${my_sqlcl_url}" E "NONE";
      my_return=1
  fi

  return ${my_return}
}

############################################################################################
# start here

# verify that we are root to run this script
if [ "x$USER" != "xoracle" ];then logMesg 1 "You must be logged in as oracle to run this script" E "NONE"; exit 1; fi

OPTIONS=$@

if checkopt_oraTools "$OPTIONS" ; then

    logMesg 0 "${SCRIPTNAME} start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check script options
    if ! inList "${tool_list}" "${ora_tool}"; then
        logMesg 1 "Incorrect Orcle tool: ${ora_tool}" E "NONE"
        error_code=1
    fi;

    # Get settings from server config file if not set on command line
    if [ -z "${ora_home:-}" ]; then ora_home=$( cfgGet "$CONF_FILE" "srvr_ora_home" ); fi

    # check for settings that can be in server config or default config
    if [ -z "${stg_dir:-}" ]; then stg_dir=$( cfgGetD "$CONF_FILE" "srvr_stg_dir" "$DEF_CONF_FILE" "stg_dir" ); fi
    if [ -z "${ora_base:-}" ]; then ora_base=$( cfgGetD "$CONF_FILE" "srvr_ora_base" "$DEF_CONF_FILE" "ora_base" ); fi

    # Provide some infomration if in test mode
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_HOME: $ora_home" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_BASE: $ora_base" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "stg_dir: $stg_dir" I "NONE" ; fi

    # run the required install
    case "${ora_tool^^}" in
        "APEX")
            logMesg 0 "APEX install not supported yet." I "NONE"
            ;;
        "SQLCL")
            logMesg 0 "Installing SQLcl under ${ora_base}/sqlcl" I "NONE"
            sqlcl_inst "${stg_dir}" "${ora_base}"
            ;;
        "AUTOUP")
            logMesg 0 "AUTOUPGRADE install not supported yet." I "NONE"
            ;;
        "ALL")
            ;;
    esac;


else
    echo "ERROR - invalid command line parameters" >&2
    error_code=2
fi

exit $error_code

#END

