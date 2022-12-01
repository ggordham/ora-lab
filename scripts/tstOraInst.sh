#!/bin/bash

# tstOraInst.sh

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# setup log file location
log_path="$( dirname "${SCRIPTDIR}" )"/log
[[ ! -d "${log_path}" ]] && /usr/bin/mkdir -p "${log_path}"
log_file="${log_path}/tstOraInst-$( date +%Y%m%d-%H%M%S ).log"
logMesg 0 "==== Log File: ${log_file}" I "NONE"

# Load configuration information from server specific configuration file
CONF_FILE="${SCRIPTDIR}"/server.conf

# Note need to add lookup for any non-defaulted values, not just known ones
disk_list=$( cfgGet "$CONF_FILE" srvr_disk_list )
ora_ver=$( cfgGet "$CONF_FILE" srvr_ora_ver )
ora_subver=$( cfgGet "$CONF_FILE" srvr_ora_subver )
stg_dir=$( cfgGet "$CONF_FILE" srvr_stg_dir )
ora_base=$( cfgGet "$CONF_FILE" srvr_ora_base )
ora_home=$( cfgGet "$CONF_FILE" srvr_ora_home )

# run Linux pre-install items
logMesg 0 "==== oraLnxPre.sh" I "NONE"
/usr/bin/sudo sh -c "${SCRIPTDIR}/oraLnxPre.sh --disks ${disk_list} >> ${log_file}"

# download and stage rquired software
logMesg 0 "==== oraSwStg.sh" I "NONE"
/usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwStg.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file}"

# run software install
/usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
/usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
logMesg 0 "==== oraSwInst.sh" I "NONE"
/usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwInst.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file}"

# configure oracle user profile
logMesg 0 "==== oraUsrCfg.sh" I "NONE"
/usr/bin/sudo sh -c "${SCRIPTDIR}/oraUsrCfg.sh >> ${log_file}"

echo "Build started: $( /bin/last | /bin/grep reboot | /bin/tail -1 )"
echo "Build finished: $( date )"
