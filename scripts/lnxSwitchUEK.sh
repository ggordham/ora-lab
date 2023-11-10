#!/bin/bash
# lnxSwitchUEK.sh 

# Red Hat Compatible Kernel (RHCK)
# Unbreakable Enterprise Kernel (UEK)

# verify that we are root to run this script
if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

# get the default kernel
default_kernel=$( /usr/sbin/grubby --default-kernel )
run_kernel=$( /usr/bin/uname -r )

echo "Current kernel: $run_kernel Installed at: $default_kernel"

case "${1}" in
  "setuek")
      echo "Switching to Unbreakable Enterprise kernel"
      # get list of kernels
      if /usr/bin/rpm --quiet -q kernel-uek.x86_64; then uek_installed=YES; else uek_installed=NO; fi
      if [ "$uek_installed" = "NO" ]; then /usr/bin/yum install -y kernel-uek.x86_64; fi
      uek_to_use=$( /usr/sbin/grubby --info=ALL | /usr/bin/grep ^kernel | /usr/bin/grep uek | head -1 )
      /usr/sbin/grubby --set-default "${uek_to_use}"
      ;;
  "setrhck")
      echo "Switching to RedHat Compatabile kernel"
      if /usr/bin/rpm --quiet -q kernel.x86_64; then rhck_installed=YES; else rhck_installed=NO; fi
      if [ "$rhck_installed" = "NO" ]; then /usr/bin/yum install -y kernel.x86_64; fi
      rhck_to_use=$( /usr/sbin/grubby --info=ALL | /usr/bin/grep ^kernel | /usr/bin/grep -Ev "uek|rescue" | /usr/bin/head -1 )
      /usr/sbin/grubby --set-default "${rhck_to_use}"
      ;;
  *)
    echo "ERROR provide kernel to set: $0 [setuek | setrhck]"
    exit 1;
    ;;
esac
#END
