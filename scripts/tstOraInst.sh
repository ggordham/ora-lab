#!/bin/bash

# tstOraInst.sh

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# setup log file location
[[ ! -d "$( basename "${SCRIPTDIR}" )"/log ]] && /usr/bin/mkdir -p "$( basename "${SCRIPTDIR}" )"/log
log_file="$( basename "${SCRIPTDIR}" )/log/tstOraInst-$( date +%Y%m%d-%H%M%S ).log"

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
/usr/bin/chmod 666 "${log_file}"
/usr/bin/chown oracle "${log_file}"
logMesg 0 "==== oraSwInst.sh" I "NONE"
/usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwInst.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file}"


