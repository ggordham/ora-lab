#!/bin/bash
# lnxSwitchUEK.sh 

# Red Hat Compatible Kernel (RHCK)
# Unbreakable Enterprise Kernel (UEK)

# verify that we are root to run this script
if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi


# get the default kernel
default_kernel=$( /usr/sbin/grubby --default-kernel )
run_kernel=$( /usr/bin/uname -r )

if /usr/bin/rpm --quiet -q kernel.x86_64; then rhck_installed=YES; else rhck_installed=NO; fi
if /usr/bin/rpm --quiet -q kernel-uek.x86_64; then uek_installed=YES; else uek_installed=NO; fi


# get list of kernels
uek_to_use=$( /usr/sbin/grubby --info=ALL | /usr/bin/grep ^kernel | /usr/bin/grep uek | head -1 )
rhck_to_use=$( /usr/sbin/grubby --info=ALL | /usr/bin/grep ^kernel | /usr/bin/grep -Ev "uek|rescue" | /usr/bin/head -1 )


# change the kernel
/usr/sbin/grubby --set-default /boot/...

/usr/bin/yum install -y kernel.x86_64
kernel-uek.x86_64
