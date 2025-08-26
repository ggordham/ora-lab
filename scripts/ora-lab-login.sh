#!/bin/bash
# ora-lab-login.sh
#
# bypass if not interactive shell
[[ ! $- =~ i ]] && exit

# sets up some basic login banner and information
SID_LIST=""
[ -f /etc/oratab ] && SID_LIST=$( /bin/grep -v -E "^#|^$|+ASM" /etc/oratab | /bin/cut -d : -f 1 | /bin/sed 'H;1h;$!d;x;s/\n/ /g' )

OS_VER=$( /bin/grep -E '^(VERSION|NAME)=' /etc/os-release | /bin/cut -f2 -d= | /bin/tr -d '"' | /bin/sed 's/\n/ /g' )

echo "------------------------------- $( /bin/date )"
echo "=== ora-lab server $( /bin/hostname -s ) on IP address $( /bin/hostname -i )"
echo "====== OS Version: $OS_VER"
echo "====== SID list:   $SID_LIST"
echo 

# check if any Oracle Homes are installed
if [ -f /etc/oraInst.loc ]; then
  echo "====== Oracle Homes:"
  ORA_INV=$( /bin/grep -E '^inventory_loc' /etc/oraInst.loc | /bin/cut -f2 -d= )
  HOME_LIST=$( /bin/grep -E '^<HOME NAME' "${ORA_INV}/ContentsXML/inventory.xml" | /bin/cut -f3 -d= | /bin/cut -f1 -d' ' | /bin/tr -d '"' )
  for h in ${HOME_LIST}; do
    echo "========= $h"
    while read -r l ; do
     if echo "${l}" | grep -E '^<ONEOFF' >/dev/null 2>&1; then
        pn=$( echo "${l}" | sed "s/ /\\n/g" | grep "REF_ID" | cut -d= -f2 | tr -d '"' )
      else
        dsc=${l//<DESC>}
        dsc=${dsc//<\/DESC>}
        echo "=========== ${pn};${dsc}"
      fi
    done < <( grep -E '^(<DESC>|<ONEOFF REF_ID)' "${h}/inventory/ContentsXML/oui-patch.xml"  )
    echo "-----------------------------"
  done
fi

