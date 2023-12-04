#!/bin/bash

# oraLnxPre.sh - Pre setup items for Linux for Oracle

# this includes 
#  - requirements to run the ora-lab scripts
#  - local storage configuration
#  - mounting any remote storage

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraLnxPre {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to prepare Linux server for ora-lab    " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--disks [list of disks to format+mount]         " >&2
  echo "--dfs   [disk fs type]                          " >&2
  echo "--sftno  Disables mounting NFS of software media" >&2
  echo "--sftt  [Software mount type]                   " >&2
  echo "--sftm  [Software mount point]                  " >&2
  echo "--sfts  [Software source]                       " >&2
  echo "--lsnp  [Oracle Listener Port]                  " >&2
  echo "--pkgs  [Linux packages to install]             " >&2
  echo "--pkgt  [Linux package tool]                    " >&2
  echo "--guser Create grid user and ASM groups         " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraLnxPre {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    SFT_MOUNT=TRUE
    grid_user=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,sftno,guser,disks:,dfs:,sftt:,sftm:,sfts:,lsnp:,pkgs:,pkgt: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraLnxPre                          #  help
                     exit 1;;
          "--disks") disk_list="$2"
                     shift 2;;
          "--dfs") fs_type="$2"
                     shift 2;;
          "--sftt") sft_type="$2"
                     shift 2;;
          "--sftm") sft_mount="$2"
                     shift 2;;
          "--sfts") sft_source="$2"
                     shift 2;;
          "--sftno") SFT_MOUNT=FALSE
                     shift ;;
           "--lsnp") lsnr_port="$2"
                     shift 2;;
           "--pkgs") lnx_pkgs="$2"
                     shift 2;;
           "--pkgt") lnx_pkg_tool="$2"
                     shift 2;;
          "--guser") grid_user=TRUE
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

if checkopt_oraLnxPre "$OPTIONS" ; then

    logMesg 0 "oraLnxPre.sh start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if required settings are set, otherwise load from config file
    if [ -z "${disk_list:-}" ]; then disk_list=$( cfgGetD "$CONF_FILE" srvr_disk_list "$DEF_CONF_FILE" disk_list ); fi
    if [ -z "${fs_type:-}" ]; then fs_type=$( cfgGetD "$CONF_FILE" srvr_fs_type "$DEF_CONF_FILE" fs_type ); fi
 
    if [ -z "${sft_type:-}" ]; then sft_type=$( cfgGetD  "$CONF_FILE" srvr_sft_type "$DEF_CONF_FILE" sft_type ); fi
    if [ -z "${sft_mount:-}" ]; then sft_mount=$( cfgGetD "$CONF_FILE" srvr_sft_mount  "$DEF_CONF_FILE" sft_mount ); fi
    if [ -z "${sft_source:-}" ]; then sft_source=$( cfgGetD "$CONF_FILE" srvr_sft_source  "$DEF_CONF_FILE" sft_source ); fi
    if [ -z "${lsnr_port:-}" ]; then lsnr_port=$( cfgGetD "$CONF_FILE" srvr_ora_lsnr_port  "$DEF_CONF_FILE" lsnr_port ); fi
    if [ -z "${lnx_pkgs:-}" ]; then lnx_pkgs=$( cfgGetD "$CONF_FILE" srvr_lnx_pkgs  "$DEF_CONF_FILE" lnx_pkgs ); fi
    if [ -z "${lnx_pkg_tool:-}" ]; then lnx_pkg_tool=$( cfgGetD "$CONF_FILE" srvr_lnx_pkg_tool  "$DEF_CONF_FILE" lnx_pkg_tool ); fi

    # check if grid user and group settings are in the config file
    # TRUE anywhere overides false in this case
    cfg_grid_user=$( cfgGetD "$CONF_FILE" srvr_grid_user  "$DEF_CONF_FILE" grid_user );
    if [ "${cfg_grid_user^^}" == "TRUE" ] || [ "${grid_user}" == "TRUE" ]; then grid_user="TRUE"; fi

    # output some test information
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "disk_list: $disk_list" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "fs_type: $fs_type" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "sft_type: $sft_type" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "sft_mount: $sft_mount" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "sft_source: $sft_source" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "lsnr_port: $lsnr_port" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "lnx_pkgs: $lnx_pkgs" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "lnx_pkg_tool: $lnx_pkg_tool" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "grid_user: $grid_user" I "NONE" ; fi

    # setup local disks
    for disk in $( echo "${disk_list}" | /bin/tr "," " " ); do
        mount=$( echo "${disk}" | /bin/cut -d : -f 1 )
        disk=$( echo "${disk}" | /bin/cut -d : -f 2 )
        label=$( /bin/basename "$mount" )
        logMesg 0 "Setting up local storage: fs: $mount disk: $disk " I "NONE"
        if [ -b "${disk}" ]; then
            sudo su -c "/bin/mkdir -p ${mount}"
            sudo su -c "/bin/chmod 755 ${mount}"
            sudo su -c "/sbin/mkfs.${fs_type} -L ${label} ${disk}"
            sudo su -c "echo 'LABEL=${label} ${mount} ${fs_type} defaults 0 0' >> /etc/fstab"
            sudo sh -c "/bin/mount ${mount}"
        else
            logMesg 1 "Could not find block device:$disk " E "NONE"
            exit 1
        fi
    done

    # Setup ownership for directories (future work
    #ora_base
    #srvr_ora_base
    #ora_db_data

    # install required packages
    if [ "${lnx_pkgs}" == "" ]; then
        logMesg 0 "No extra Linux packages to install." I "NONE"
    else
        logMesg 0 "Installing extra Linux packages: ${lnx_pkgs}" I "NONE"
        sudo sh -c "${lnx_pkg_tool} -y install $( echo "${lnx_pkgs}" | tr "," " " )"
    fi
    
    # Enable RNGD
    if /usr/bin/rpm --quiet -q rng-tools ; then
        logMesg 0 "Enabeling RNGD " I "NONE"
        sudo sh -c "/bin/systemctl enable rngd"
        sudo sh -c "/bin/systemctl start rngd"
    else
        logMesg 0 "RNGD not installed, skipping enablement" I "NONE"
    fi

    # Add grid user and ASM groups if needed
    if [ "$grid_user" == "TRUE" ]; then
        logMesg 0 "Adding grid user and ASM groups " I "NONE"
        /sbin/groupadd -g 54327 asmdba
        /sbin/groupadd -g 54328 asmoper
        /sbin/groupadd -g 54329 asmadmin
        /sbin/useradd -N -s /bin/bash -i 54331 -g oinstall -G asmdba,asoper,asmadmin grid 
        
        logMesg 0 "Adding oracle user to all ASM groups " I "NONE"
        /sbin/usermod -aG asmdba,asmoper,asmadmin oracle

        # for grid install, listener configuration has issues with IPv6 line in hosts file
        /bin/sed -i "/^::1 $( /bin/hostname )/d" /etc/hosts
    fi

    # make additional oradata folders
    for disk in $( echo "${disk_list}" | /bin/tr "," " " ); do
        mount=$( echo "${disk}" | /bin/cut -d : -f 1 )
        if [ "${mount}" != "/u01" ]; then
             sudo sh -c "/bin/mkdir -p ${mount}/oradata"
             sudo sh -c "/usr/bin/chown oracle ${mount}/oradata"
             sudo sh -c "/usr/bin/chgrp oinstall ${mount}/oradata"
        fi
    done
     
    # Configure firewalld for Oracle Listener
    logMesg 0 "Updating firewalld for oracle port: ${lsnr_port}" I "NONE"
    sudo sh -c "/bin/firewall-cmd --permanent --zone=public --add-port=${lsnr_port}/tcp"
    sudo sh -c "/bin/firewall-cmd --reload"

    # Setup software mount
    if [ "$SFT_MOUNT" == "TRUE" ]; then
        logMesg 0 "Setting up software mount: $sft_mount" I "NONE"
        fs_opts="ro,_netdev 0 0"
        logMesg 0 "Updating fstab" I "NONE"
        echo "${sft_source} ${sft_mount} ${sft_type} ${fs_opts}" | sudo tee -a /etc/fstab
        sudo sh -c "/bin/mkdir ${sft_mount}"
        sudo sh -c "/bin/mount ${sft_mount}"
        if /bin/mountpoint "${sft_mount}"; then logMesg 0 "Sucess mounting: ${sft_mount}" I "NONE"
        else logMesg 1 "Faild to mount: $sft_mount" E "NONE"; exit 1; fi
    else
        logMesg 0 "Software Mount disabled with option --sftno" I "NONE";
    fi

    logMesg 0 "oraLnxPre.sh finished" I "NONE"

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END

