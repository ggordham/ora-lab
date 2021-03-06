#!/bin/bash 
# oraSwInst.sh - install Oracle Software

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source oralab.shlib

# Test variables
CONF_FILE=ora_inst_files.conf

# retun command line help information
function help_oraSwInst {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to install Oracle DB software          " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--oraver [Oracle version]                       " >&2
  echo "--orasubver [Oracle minor version]              " >&2
  echo "--orabase [Oracle base]                         " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--srcdir [Source directory]                     " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraSwInst {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,srcdir:,oraver:,orasubver:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraSwInst                          #  help
                     exit 1;;
          "--oraver") ora_ver="$2"
                     shift 2;;
          "--orasubver") ora_sub_ver="$2"
                     shift 2;;
          "--srcdir") src_dir="$2"
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

############################################################################################
# start here

OPTIONS=$@

if checkopt_oraSwInst "$OPTIONS" ; then

    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if a ORACLE_BASE was set, otherwise lookup default setting
    if [ -z "${ora_base:-}" ]; then ora_base=$( cfgGet "$CONF_FILE" ora_base ); fi
    if [ -z "${ora_home:-}" ]; then ora_home="${ora_base}/product/${ora_ver}/dbhome_1"; fi
    ora_inst=$( dirname "${ora_base}" )
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_BASE: $ora_base" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_INST: $ora_inst" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_HOME: $ora_home" I "NONE" ; fi

    # ora_vers=$( cfgGet "${CONF_FILE}" main_versions )
    if inListC "$( cfgGet "${CONF_FILE}" main_versions )" "${ora_ver}" ; then
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "Found version: $ora_ver" I "NONE" ; fi
        install_type=$( cfgGet "${CONF_FILE}" "${ora_ver}_install_type" )
        main_file=$( cfgGet "${CONF_FILE}" "${ora_ver}_main" )
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "install_type: $install_type" I "NONE" ; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "main_file: $main_file" I "NONE" ; fi

        # check if src_dir is set otherwise pull from default setting
        if [ -z "${src_dir:-}" ]; then 
            src_base=$( cfgGet "$CONF_FILE" src_base )
            src_dir="${src_base}$( cfgGet "$CONF_FILE" "${ora_ver}_src_dir" )"
        fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "src_dir: $src_dir" I "NONE" ; fi

        # if install type is unzip for 18c and above
        if [ "$install_type" = "unzip" ]; then

            # looking up RU patches
            ru_list=$( cfgGet "${CONF_FILE}" "${ora_sub_ver}_RU" )
            one_off=$( cfgGet "${CONF_FILE}" "${ora_sub_ver}_ONEOFF" )

            if [ "$TEST" == "TRUE" ]; then logMesg 0 "ru_list: $ru_list" I "NONE" ; fi
            if [ "$TEST" == "TRUE" ]; then logMesg 0 "one_off: $one_off" I "NONE" ; fi

            # setting up command line paramters
            cmd_parms=""
            if [ "$ru_list" != "__UNDEFINED__" ]; then cmd_parms="-applyRU $ru_list"; fi
            if [ "$one_off" != "__UNDEFINED__" ]; then cmd_parms="$cmd_parms -applyOneOffs $one_off"; fi

            cmd_parms="$cmd_parms -silent -ignoreprereqfailure oracle.install.option=INSTALL_DB_SWONLY"
            cmd_parms="$cmd_parms UNIX_GROUP_NAME=oinstall"
            cmd_parms="$cmd_parms INVENTORY_LOCATION=$ora_inst"
            cmd_parms="$cmd_parms ORACLE_HOME=$ora_home"
            cmd_parms="$cmd_parms ORACLE_HOME_NAME=DB_${ora_sub_ver}"
            cmd_parms="$cmd_parms ORACLE_BASE=$ora_base"
            cmd_parms="$cmd_parms oracle.install.db.InstallEdition=EE"
            cmd_parms="$cmd_parms oracle.install.db.OSDBA_GROUP=dba"
            cmd_parms="$cmd_parms oracle.install.db.OSOPER_GROUP=dba"
            cmd_parms="$cmd_parms oracle.install.db.OSBACKUPDBA_GROUP=dba"
            cmd_parms="$cmd_parms oracle.install.db.OSDGDBA_GROUP=dba"
            cmd_parms="$cmd_parms oracle.install.db.OSKMDBA_GROUP=dba"
            cmd_parms="$cmd_parms oracle.install.db.OSRACDBA_GROUP=dba"
            cmd_parms="$cmd_parms DECLINE_SECURITY_UPDATES=true"

            if [ "$TEST" == "TRUE" ]; then logMesg 0 "Install CMD: ${ora_home}/runInstaller $cmd_parms" I "NONE"; fi
        fi

    else
        echo "ERROR! Did not find version: $ora_ver"
    fi

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END



