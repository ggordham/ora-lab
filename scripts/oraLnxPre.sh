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

# Internal variables
CONF_FILE="${SCRIPTDIR}"/linux_pre.conf

# retun command line help information
function help_oraLnxPre {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to prepare Linux server for ora-lab    " >&2
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

disk_list=/u01:/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1,/u02:/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi2
fs_type=xfs

sft_type=nfs
sft_mount=/mnt/software
sft_source=freenas-priv1:/mnt/Pool1/Software

lsnr_port=1521
lnx_pkgs=git,ansible,wget,rng-tools,nfs-utils
lnx_pkg_tool=/bin/yum

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


# setup local disks
for disk in $( echo ${disk_list} | /bin/tr "," " " ); do
    mount=$( echo "${disk}" | /bin/cut -d : -f 1 )
    disk=$( echo "${disk}" | /bin/cut -d : -f 1 )
    label=$( /bin/basename "$mount" )
    logMesg 0 "Setting up local storage: fs: $mount disk: $disk " I "NONE"
    if [ -b "${disk}" ]; then
        sudo su -c "/bin/mkdir -p ${mount}"
        sudo su -c "/bin/chmod 755 ${mount}"
        sudo su -c "/sbin/mkfs.${fs_type} -L ${label} ${disk}"
        sudo su -c "echo 'LABEL=${label} ${mount} ${fs_type} defaults 0 0' >> /etc/fstab"
        sudo sh -c "/bin/mount ${mount}"
    else
        logMesg 1 "Cloud not find block device:$disk " E "NONE"
        exit 1
    fi
done

# install required packages
logMesg 0 "Installing extra Linux packages: ${lnx_pkgs}" I "NONE"
sudo sh -c "${lnx_pkg_tool} -y install $( echo ${lnx_pkgs} | tr "," " " )"

# Enable RNGD
logMesg 0 "Enabeling RNGD " I "NONE"
sudo sh -c "/bin/systemctl enable rngd"
sudo sh -c "/bin/systemctl start rngd"

# Configure firewalld for Oracle Listener
logMesg 0 "Updating firewalld for oracle port: ${lsnr_port}" I "NONE"
sudo sh -c "/sbin/firewall-cmd --permanent --zone=public --add-port=${lsnr_port}/tcp"
sudo sh -c "/sbin/firewall-cmd --reload"

# Setup software mount
logMesg 0 "Setting up software mount: $sft_mount" I "NONE"
fs_opts="ro,_netdev 0 0"
logMesg 0 "Updating fstab" I "NONE"
echo "${sft_source} ${sft_mount} ${sft_type} ${fs_opts}" | sudo tee -a /etc/fstab
sudo sh -c "/bin/mkdir ${sft_mount}"
sudo sh -c "/bin/mount ${sft_mount}"
if /bin/mountpoint "${sft_mount}"; then logMesg 0 "Sucess mounting: ${sft_mount}" I "NONE"
else logMesg 1 "Faild to mount: $sft_mount" E "NONE"; exit 1; fi

