#!/bin/bash

# oraSwStg.sh - Stage Oracle software and patches

# Internal settings, export empty variable that is set by library
export SCRIPTDIR
SCRIPTVER=1.1
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib
error_code=0

# retun command line help information
function help_oraSwStg {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to stage Oracle DB software + patches  " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--oratype [grid | db]                           " >&2
  echo "--oraver [Oracle version]                       " >&2
  echo "--orasubver [Oracle minor version]              " >&2
  echo "--orabase [Oracle base]                         " >&2
  echo "--orahome [Oracle home]                         " >&2
  echo "--srcdir [Source directory]                     " >&2
  echo "--stgdir [Staging Directory]                    " >&2
  echo "--guser Create grid user and ASM groups         " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraSwStg {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    GRID_USER=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,guser,srcdir:,oratype:,oraver:,orasubver:,stgdir:,orabase:,orahome: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraSwStg                          #  help
                     exit 1;;
          "--oratype") ora_type="$2"
                     shift 2;;
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
          "--guser") GRID_USER=TRUE
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

# verify that we are root to run this script
if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

OPTIONS=$@

if checkopt_oraSwStg "$OPTIONS" ; then

    logMesg 0 "${SCRIPTNAME} start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # Default the ora_type to database to perserve original design of script
    if [ -z "${ora_type:-}" ]; then ora_type=DB; fi
    # make sure parameter is uppercase
    ora_type=${ora_type^^}
    # check install type
    case "${ora_type}" in
       "DB") conf_var=ora;    conf_user=oracle;;
       "GRID") conf_var=grid; conf_user=grid;;
       *) logMesg 1 "Incorrect install type (oratype) of: ${ora_type}" E "NONE";
          exit 1;;
    esac

    logMesg 0 "Install type of: $ora_type" "NONE"

    # Get settings from server config file if not set on command line
    if [ -z "${ora_ver:-}" ]; then ora_ver=$( cfgGet "$CONF_FILE" "srvr_${conf_var}_ver" ); fi
    if [ -z "${ora_sub_ver:-}" ]; then ora_sub_ver=$( cfgGet "$CONF_FILE" "srvr_${conf_var}_subver" ); fi
    if [ -z "${ora_home:-}" ]; then ora_home=$( cfgGet "$CONF_FILE" "srvr_${conf_var}_home" ); fi

    # For oracle home we have a default setting if it is not set
    if [ "${ora_type}" == "DB" ] && ( [ -z "${ora_home:-}" ] || [ "${ora_home}" == "__UNDEFINED__" ] ); then ora_home="${ora_base}/product/${ora_ver}/dbhome_1"; fi
    if [ "${ora_type}" == "GRID" ] && ( [ -z "${ora_home:-}" ] || [ "${ora_home}" == "__UNDEFINED__" ] ); then ora_home="$( /usr/bin/dirname "${ora_base}" )/${ora_ver}/grid_1"; fi

    # check for settings that can be in server config or default config
    if [ -z "${stg_dir:-}" ]; then stg_dir=$( cfgGetD "$CONF_FILE" "srvr_stg_${conf_var}_dir" "$DEF_CONF_FILE" "stg_${conf_var}_dir" ); fi
    if [ -z "${ora_base:-}" ]; then ora_base=$( cfgGetD "$CONF_FILE" "srvr_${conf_var}_base" "$DEF_CONF_FILE" "${conf_var}_base" ); fi
    ora_inst=$( /usr/bin/dirname "${ora_base}" )

    # check if grid user and group settings are in the config file
    # TRUE anywhere overides false in this case
    cfg_grid_user=$( cfgGetD "$CONF_FILE" srvr_grid_user  "$DEF_CONF_FILE" grid_user );
    if [ "${cfg_grid_user^^}" == "TRUE" ] || [ "${GRID_USER}" == "TRUE" ]; then GRID_USER="TRUE"; fi

    # Provide some infomration if in test mode
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_ver: $ora_ver" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_sub_ver: $ora_sub_ver" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_HOME: $ora_home" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_BASE: $ora_base" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORACLE_INST: $ora_inst" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "stg_dir: $stg_dir" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "GRID_USER: $GRID_USER" I "NONE" ; fi

    # setup staging directory
    if [ "${stg_dir}" != "__UNDEFINED__" ]; then
        logMesg 0 "Making patch staging directory: $stg_dir" I "NONE"
        [ ! -d "${stg_dir}" ] && /usr/bin/mkdir -p "${stg_dir}"
        /usr/bin/mkdir -p "${stg_dir}/patch"
    else
        error_code=3
        logMesg 1 "Failed to setup stg_dir: $stg_dir " E "NONE"
    fi

    # check if the version and subversion are valid, and lookup settings for this version
    if inListC "$( cfgGet "${ORA_CONF_FILE}" main_versions )" "${ora_ver}"  && inListC "$( cfgGet "${ORA_CONF_FILE}" "${ora_ver}_sub_versions" )" "${ora_sub_ver}" ; then
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "Found version: $ora_ver" I "NONE" ; fi
        install_type=$( cfgGet "${ORA_CONF_FILE}" "${ora_ver}_install_type" )
        case "${ora_type}" in
           "DB") main_file=$( cfgGet "${ORA_CONF_FILE}" "${ora_ver}_db" );;
           "GRID") main_file=$( cfgGet "${ORA_CONF_FILE}" "${ora_ver}_grid" );;
        esac

        if [ "$TEST" == "TRUE" ]; then logMesg 0 "install_type: $install_type" I "NONE" ; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "main_file: $main_file" I "NONE" ; fi

        # check if src_dir is set otherwise pull from default setting
        if [ -z "${src_dir:-}" ]; then 
            src_base=$( cfgGet "$ORA_CONF_FILE" src_base )
            src_dir="${src_base}$( cfgGet "$ORA_CONF_FILE" "${ora_ver}_src_dir" )"
        fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "src_dir: $src_dir" I "NONE" ; fi

        # install the required database pre-install RPM
        preinstall_rpm=$( cfgGet "${ORA_CONF_FILE}" "${ora_ver}_pre_install" )
        if [ "$preinstall_rpm" == "__UNDEFINED__" ]; then logMesg 1 "Pre Install RPM not found for $ora_ver" E "NONE"; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "preinstall_rpm: $preinstall_rpm" I "NONE" 
          elif [ -f /usr/bin/dnf ]; then /usr/bin/dnf -y install "${preinstall_rpm}"
          else /bin/yum -y install "${preinstall_rpm}"; fi

        # Add grid user and ASM groups if needed, setup OS limits
        if [ "${GRID_USER}" == "TRUE" ]; then
            logMesg 0 "Adding grid user and ASM groups " I "NONE"
            /sbin/groupadd -g 54327 asmdba
            /sbin/groupadd -g 54328 asmoper
            /sbin/groupadd -g 54329 asmadmin
            /sbin/useradd -N -s /bin/bash -u 54331 -g oinstall -G asmdba,asmoper,asmadmin grid 
            
            logMesg 0 "Adding oracle user to all ASM groups " I "NONE"
            /sbin/usermod -aG asmdba,asmoper,asmadmin oracle

            # Setup grid user OS limits
            /bin/cp /etc/security/limits.d/oracle-database-preinstall-19c.conf /etc/security/limits.d/oracle-grid-preinstall-19c.conf
            /bin/sed -i 's/^oracle./grid/g' /etc/security/limits.d/oracle-grid-preinstall-19c.conf
        fi

        logMesg 0 "Creating install directories" I "NONE"
        # Setup the required directories for install
        if [ "${ora_base}" != "__UNDEFINED__" ]; then /usr/bin/mkdir -p "${ora_base}"; else error_code=3; fi
        if [ "${ora_home}" != "__UNDEFINED__" ]; then /usr/bin/mkdir -p "${ora_home}"; else error_code=3; fi
        if [ "${ora_inst}" != "__UNDEFINED__" ]; then /usr/bin/mkdir -p "${ora_inst}"; else error_code=3; fi
        [ -d "${ora_base}" ] && /usr/bin/chown -R "${conf_user}":oinstall "${ora_base}"
        [ -d "${ora_home}" ] && /usr/bin/chown -R "${conf_user}":oinstall "${ora_home}"
        [ -d "${ora_inst}" ] && /usr/bin/chown "${conf_user}":oinstall "${ora_inst}"
        if (( error_code > 0 )); then logMesg 1 "Failed to setup ora_base: $ora_base ora_home: $ora_home ora_inst: $ora_inst" E "NONE"; fi

        # make sure stage directory is owned by software owner user
        /usr/bin/chown -R "${conf_user}":oinstall "${stg_dir}"
        if [ ! -d "${stg_dir}" ]; then 
            logMesg 1 "could not access stage directory: $stg_dir" E "NONE" 
            exit 1
        fi 

        # if legacy runinstall, make staging software location
        if [ "$install_type" == "runinstall" ]; then
            # legacy runinstall setup, stage software
            /usr/bin/mkdir -p "${stg_dir}/${conf_var}media"
            /usr/bin/chown -R "${conf_user}":oinstall "${stg_dir}"
        fi

        logMesg 0 "Staging Oracle database software" I "NONE"
        # Stage the Oracle software to the right location
        for m_file in $( echo "$main_file" | tr "," " " ); do
            if [ -f "${src_dir}/${m_file}" ]; then 
                case "$install_type" in
                    "unzip")
                        # for 18c and above unzip the source media to the home location
                        if [ "$TEST" == "TRUE" ]; then logMesg 0 "not unziping $m_file to $ora_home" I "NONE" 
                          else /usr/bin/su "${conf_user}" -c "/usr/bin/unzip -q -o ${src_dir}/${m_file} -d ${ora_home}"; fi
                        ;;
                    "runinstall")
                        # for legacy runisntall setup stage media
                        if [ "$TEST" == "TRUE" ]; then logMesg 0 "not staging runinstall $m_file to $stg_dir" I "NONE" 
                          else /usr/bin/su "${conf_user}" -c "/usr/bin/unzip -q -o ${src_dir}/${m_file} -d ${stg_dir}"; fi
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
        case "${ora_type}" in
           "DB") 
               ru_list=$( cfgGet "${ORA_CONF_FILE}" "${ora_sub_ver}_RU" )
               one_off=$( cfgGet "${ORA_CONF_FILE}" "${ora_sub_ver}_ONEOFF" );;

           "GRID") 
               ru_list=$( cfgGet "${ORA_CONF_FILE}" "${ora_sub_ver}_GI" )
               one_off=$( cfgGet "${ORA_CONF_FILE}" "${ora_sub_ver}_GI_ONEOFF" );;
        esac

        if [ "$TEST" == "TRUE" ]; then logMesg 0 "ru_list: $ru_list" I "NONE" ; fi
        if [ "$TEST" == "TRUE" ]; then logMesg 0 "one_off: $one_off" I "NONE" ; fi

        # Download patches
        # getMOSPatch requires wget
        # /bin/yum -y install wget  # perl no longer needed by v 1.3 of getMOSPatch.sh
        logMesg 0 "Downloading Oracle patches" I "NONE"
        # Note for future: "541P;Linux ARM 64-bit"
        echo "226P;Linux x86-64" > "${SCRIPTDIR}/.getMOSPatch.sh.cfg"
        mosUser=$( getSecret "MOSUSER" )
        mosPass=$( getSecret "MOSPASS" )
        export mosUser mosPass

        # Generate a list of patches for RU and One Offs
        if [ "$ru_list" == "__UNDEFINED__" ]; then logMesg 0 "No RU patch to download for $ora_sub_ver" I "NONE"
            else p_list="$ru_list"; logMesg 0 "RU patches: $ru_list" I "NONE"; fi
        if [ "$one_off" == "__UNDEFINED__" ]; then logMesg 0 "No one off patchs to download for $ora_sub_ver" I "NONE"
            elif [ "$p_list" == "" ]; then p_list="${one_off}"; logMesg 0 "One off patche: $one_off" I "NONE"
            else p_list="${p_list},${one_off}"; logMesg 0 "One off patche: $one_off" I "NONE"; fi

        # Loop through each patch and download
        for p_patch in $( echo "$p_list" | /bin/tr "," " " ); do
            logMesg 0 "Downloading and unzipping Patch: $p_patch" I "NONE"
            if [ "$DEBUG" == "TRUE" ]; then debug_flag="debug=yes"; else debug_flag=""; fi

            # if we are in test mode do not download the patch
            if [ "$TEST" == "TRUE" ]; then 
                logMesg 0 "Test Mode - not running:" I "NONE" 
                logMesg 0 "${SCRIPTDIR}/getMOSPatch.sh patch=$p_patch destination=${stg_dir}/patch ${debug_flag}" I "NONE"
            else
                "${SCRIPTDIR}/getMOSPatch.sh" patch="$p_patch" destination="${stg_dir}/patch" "${debug_flag}"
                error_code=$?
                # for some one off patches there will be subversions by RU.  We will try to check 
                #   the RU number with regexp
                if (( error_code > 0 )); then
                    "${SCRIPTDIR}/getMOSPatch.sh" patch="$p_patch" regexp="${ora_sub_ver/_}" destination="${stg_dir}/patch" "${debug_flag}"
                    error_code=$?
                fi
                # if things are good unzip the patch file
                if (( error_code == 0 )); then
                    p_file="$( ls "${stg_dir}/patch/p${p_patch}"*.zip )"
                    [[ -f "$p_file" ]] && chown "${conf_user}":oinstall "${p_file}"
                    [[ -f "$p_file" ]] && /usr/bin/su "${conf_user}" -c "/usr/bin/unzip -q -o ${p_file} -d ${stg_dir}/patch"
                else
                    # for some one off patches there will be subversions by RU.  We will try to check 
                    #   the RU number with regexp
                        
                    logMesg 0 "Could not download patch: $p_patch" E "NONE"
                fi 
            fi
        done

        # only continue if no errors detected so far
        if (( error_code == 0 )); then
            # Download the OPatch for this version
            logMesg 0 "Downloading OPatch" I "NONE"
            opatch_ver=$( cfgGet "${ORA_CONF_FILE}" "${ora_ver}_opatch" )
            if [ "$opatch_ver" == "__UNDEFINED__" ]; then 
                logMesg 0 "No OPatch to download for $ora_ver" I "NONE"
            else
                if [ "$TEST" == "TRUE" ]; then logMesg 0 "opatch_ver: $opatch_ver" I "NONE" ; fi
                p_patch=6880880
                if [ "$DEBUG" == "TRUE" ]; then debug_flag="debug=yes"; else debug_flag=""; fi
                # if we are in test mode do not download the patch
                if [ "$TEST" == "TRUE" ]; then 
                    logMesg 0 "Test Mode - not running:" I "NONE" 
                    logMesg 0 "${SCRIPTDIR}/getMOSPatch.sh patch=${p_patch} regexp=${opatch_ver} destination=${stg_dir}/patch ${debug_flag}" I "NONE"
                    logMesg 0 "test mode not unziping OPatch file to $ora_home" I "NONE"
                else
                    "${SCRIPTDIR}/getMOSPatch.sh" patch="${p_patch}" regexp="${opatch_ver}" destination="${stg_dir}/patch" "${debug_flag}"
                    error_code=$?
                    if [ "$DEBUG" == "TRUE" ]; then logMsg 0 "getMOSPatch.sh tmp2 file: $( cat "${SCRIPTDIR}/.getMosPatch.sh.tmp2" )" I "NONE" ; fi
                    # if things are good unzip the OPatch file
                    if (( error_code == 0 )); then
                        p_file="$( ls "${stg_dir}/patch/p${p_patch}"*.zip )"
                        if [ "$TEST" == "TRUE" ]; then logMesg 0 "opatch_file: $p_file" I "NONE" ; fi
                        [[ -f "$p_file" ]] && chown "${conf_user}":oinstall "${p_file}"
                        # don't need to unzip the OPatch file in staging location
                        # [[ -f "$p_file" ]] && /usr/bin/su "${conf_user}" -c "/usr/bin/unzip -q -o ${p_file} -d ${stg_dir}/patch"
                    else
                        logMesg 0 "Could not download opatch: $p_patch" E "NONE"
                    fi 
                    # if unzip install type then update OPatch in place
                    if [ "$install_type" == "unzip" ]; then
                        [[ -f "$p_file" ]] && /usr/bin/su "${conf_user}" -c "/usr/bin/rm -Rf ${ora_home}/OPatch"
                        [[ -f "$p_file" ]] && /usr/bin/su "${conf_user}" -c "/usr/bin/unzip -q -o ${p_file} -d ${ora_home}"
                    fi
                fi
            fi # end of OPatch work
        fi 

        logMesg 0 "Completed $SCRIPTNAME" I "NONE"

    else
        # Version of Oracle not found in config file
        logMesg 0 "ERROR! Did not find version: $ora_ver or subversion: $ora_sub_ver in config file $ORA_CONF_FILE" E "NONE"
        error_code=2
    fi

    logMesg 0 "${SCRIPTNAME} finished" I "NONE"

else
    echo "ERROR - invalid command line parameters" >&2
    error_code=2
fi

exit $error_code

#END

