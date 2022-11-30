#!/bin/bash

# oraSwStg.sh - Stage Oracle software and patches

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# Test variables
CONF_FILE="${SCRIPTDIR}"/ora_inst_files.conf

# retun command line help information
function help_oraSwStg {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to stage Oracle DB software + patches  " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--oraver [Oracle version]                       " >&2
  echo "--orasubver [Oracle minor version]              " >&2
  echo "--orabase [Oracle base]                         " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--srcdir [Source directory]                     " >&2
  echo "--stgdir [Staging Directory]                    " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraSwStg {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,srcdir:,oraver:,orasubver:,stgdir:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
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

############################################################################################
# start here

# verify that we are root to run this script
if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

OPTIONS=$@

if checkopt_oraSwStg "$OPTIONS" ; then

    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if a ORACLE_BASE was set, otherwise lookup default setting
    if [ -z "${ora_base:-}" ]; then ora_base=$( cfgGet "$CONF_FILE" ora_base ); fi
    if [ -z "${ora_home:-}" ]; then ora_home="${ora_base}/product/${ora_ver}/dbhome_1"; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_BASE: $ora_base" I "NONE" ; fi
    ora_inst=$( dirname "${ora_base}" )
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_INST: $ora_inst" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_HOME: $ora_home" I "NONE" ; fi

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

        # install the required database pre-install RPM
        preinstall_rpm=$( cfgGet "${CONF_FILE}" "${ora_ver}_pre_install" )
        if [ "$preinstall_rpm" == "__UNDEFINED__" ]; then logMesg 1 "Pre Install RPM not found for $ora_ver" E "NONE"; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "preinstall_rpm: $preinstall_rpm" I "NONE" 
          else /bin/yum -y install "${preinstall_rpm}"; fi

        logMesg 0 "Creating install directories" I "NONE"
        # Setup the required directories for install
        /usr/bin/mkdir -p "${ora_base}"
        /usr/bin/mkdir -p "${ora_home}"
        /usr/bin/mkdir -p "${ora_inst}"
        /usr/bin/chown -R oracle:oinstall "${ora_base}"
        /usr/bin/chown -R oracle:oinstall "${ora_home}"
        /usr/bin/chown -R oracle:oinstall "${ora_inst}"
        if [ ! -d "${ora_base}" ]; then logMesg 1 "Failed to setup install directory $ora_base" E "NONE"; fi

        # if legacy runinstall, make staging software location
        if [ "$install_type" == "runinstall" ]; then
            # legacy runinstall setup, stage software
            /usr/bin/mkdir -p "${stg_dir}/oramedia"
            /usr/bin/chown -R oracle:oinstall "${stg_dir}"
        fi

        logMesg 0 "Staging Oracle database software" I "NONE"
        # Stage the Oracle software to the right location
        for m_file in $( echo "$main_file" | tr "," " " ); do
            if [ -f "${src_dir}/${m_file}" ]; then 
                case "$install_type" in
                    "unzip")
                        # for 18c and above unzip the source media to the home location
                        if [ "$TEST" == "TRUE" ]; then logMesg 0 "not unziping $m_file to $ora_home" I "NONE" 
                          else /usr/bin/su oracle -c "/usr/bin/unzip -q -o -d ${ora_home} ${src_dir}/${m_file}"; fi
                        ;;
                    "runinstall")
                        # for legacy runisntall setup stage media
                        if [ "$TEST" == "TRUE" ]; then logMesg 0 "not staging runinstall $m_file to $stg_dir" I "NONE" 
                          else /usr/bin/su oracle -c "/usr/bin/unzip -q -o -d ${stg_dir} ${src_dir}/${m_file}"; fi
                        ;;
                    *)
                        logMesg 1 "Unsupported install type $install_type" E "NONE";;
                esac
            else
                logMesg 1 "Failed to find main file: ${src_dir}/${m_file}" E "NONE"; 
            fi 
        done

        # Stage the Oracle patches
        # looking up RU patches
        ru_list=$( cfgGet "${CONF_FILE}" "${ora_sub_ver}_RU" )
        one_off=$( cfgGet "${CONF_FILE}" "${ora_sub_ver}_ONEOFF" )

        if [ "$TEST" == "TRUE" ]; then logMesg 0 "ru_list: $ru_list" I "NONE" ; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "one_off: $one_off" I "NONE" ; fi

        logMesg 0 "Making patch staging directories" I "NONE"
        /usr/bin/mkdir -p "${stg_dir}/patch"
        /usr/bin/chown -R oracle:oinstall "${stg_dir}"

        # Download patches
        # getMOSPatch requires wget
        # /bin/yum -y install wget  # perl no longer needed by v 1.3 of getMOSPatch.sh
        logMesg 0 "Downloading Oracle patches" I "NONE"
        echo "226P;Linux x86-64" > "${SCRIPTDIR}/.getMOSPatch.sh.cfg"
        mosUser=$( cfgGet "${SCRIPTDIR}/secure.conf" "MOSUSER" )
        mosPass=$( cfgGet "${SCRIPTDIR}/secure.conf" "MOSPASS" )
        export mosUser mosPass

        # Generate a list of patches for RU and One Offs
        if [ "$ru_list" == "__UNDEFINED__" ]; then logMesg 0 "No RU patch to download for $ora_sub_ver" I "NONE"
            else p_list="$ru_list"; logMesg 0 "RU patches: $ru_list" I "NONE"; fi
        if [ "$one_off" == "__UNDEFINED__" ]; then logMesg 0 "No one off patchs to download for $ora_sub_ver" I "NONE"
            elif [ "$p_list" == "" ]; then p_list="${one_off}"; logMesg 0 "One off patche: $one_off" I "NONE"
            else p_list="${p_list},${one_off}"; logMesg 0 "One off patche: $one_off" I "NONE"; fi

        # Loop through each patch and download
        for p_patch in $( echo "$p_list" | tr "," " " ); do
            logMesg 0 "Downloading and unzipping Patch: $p_patch" I "NONE"
            "${SCRIPTDIR}/getMOSPatch.sh" patch="$p_patch" destination="${stg_dir}/patch"
            p_file="$( ls "${stg_dir}/patch/p${p_patch}"*.zip )"
            [[ -f "$p_file" ]] && chown oracle:oinstall "${p_file}"
            [[ -f "$p_file" ]] && /usr/bin/su oracle -c "/usr/bin/unzip -q -o -d ${stg_dir}/patch ${p_file}"
        done

        # Download the OPatch for this version
        logMesg 0 "Downloading OPatch" I "NONE"
        opatch_ver=$( cfgGet "${CONF_FILE}" "${ora_ver}_opatch" )
        if [ "$opatch_ver" == "__UNDEFINED__" ]; then logMesg 0 "No OPatch to download for $ora_ver" I "NONE"; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "opatch_ver: $opatch_ver" I "NONE" ; fi
        p_patch=6880880
        if [ "$DEBUG" == "TRUE" ]; then debug_flag="debug=yes"; else debug_flag=""; fi
        "${SCRIPTDIR}/getMOSPatch.sh" patch="$p_patch" regexp="$opatch_ver" destination="${stg_dir}/patch" "$debug_flag"
        if [ "$DEBUG" == "TRUE" ]; then logMsg 0 "getMOSPatch.sh tmp2 file: $( cat "${SCRIPTDIR}/.getMosPatch.sh.tmp2" )" I "NONE" ; fi

        p_file="$( ls "${stg_dir}/patch/p${p_patch}"*.zip )"
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "opatch_file: $p_file" I "NONE" ; fi
        [[ -f "$p_file" ]] && chown oracle:oinstall "${p_file}"
        [[ -f "$p_file" ]] && logMesg 0 "OPatch file downloaded: $p_file" I "NONE"

        # if unzip install type then update OPatch in place
        if [ "$install_type" == "unzip" ]; then
            if [ "$TEST" == "TRUE" ]; then logMesg 0 "not unziping OPatch $p_file to $ora_home" I "NONE" 
            else [[ -f "$p_file" ]] && /usr/bin/su oracle -c "/usr/bin/unzip -q -o -d ${ora_home} ${p_file}"; fi
        fi

        logMesg 0 "Completed $SCRIPTNAME" I "NONE"

    else
        # Version of Oracle not found in config file
        echo "ERROR! Did not find version: $ora_ver in config file $CONF_FILE"
    fi

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

