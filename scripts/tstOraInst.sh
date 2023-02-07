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

# get list of steps to run
build_steps=$( cfgGet "$CONF_FILE" build_steps )
logMesg 0 "=== Build steps: $build_steps" I "NONE"

# Note need to add lookup for any non-defaulted values, not just known ones
disk_list=$( cfgGet "$CONF_FILE" srvr_disk_list )
ora_ver=$( cfgGet "$CONF_FILE" srvr_ora_ver )
ora_subver=$( cfgGet "$CONF_FILE" srvr_ora_subver )
stg_dir=$( cfgGet "$CONF_FILE" srvr_stg_dir )
ora_base=$( cfgGet "$CONF_FILE" srvr_ora_base )
ora_home=$( cfgGet "$CONF_FILE" srvr_ora_home )


# run Linux pre-install items (pre)
if inListC "${build_steps}" "pre"; then
    logMesg 0 "==== oraLnxPre.sh (pre)" I "NONE"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraLnxPre.sh --disks ${disk_list} >> ${log_file}"
fi

# download and stage rquired software (stg)
if inListC "${build_steps}" "stg"; then
    logMesg 0 "==== oraSwStg.sh (stg)" I "NONE"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwStg.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file}"
fi

# run software install (inst)
if inListC "${build_steps}" "inst"; then
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    logMesg 0 "==== oraSwInst.sh (inst)" I "NONE"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwInst.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file}"
fi

# run database creation assistant (dbca)
if inListC "${build_steps}" "dbca"; then
    logMesg 0 "==== oraDBCA.sh (dbca)" I "NONE"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraDBCA.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraDBCA.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraDBCA.sh >> ${log_file}"
fi

# run database creation assistant (lsnr)
if inListC "${build_steps}" "lsnr"; then
    logMesg 0 "==== oraLsnr.sh (lsnr)" I "NONE"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraLsnr.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraLsnr.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraLsnr.sh >> ${log_file}"

    # create TNS entires
    # decide on what SID or PDB to use for install
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraTNS.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraTNS.sh"
    ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid )
    ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb )
    logMesg 0 "==== oraTNS.sh for $ora_db_sid" I "NONE"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraTNS.sh --dbservice ${ora_db_sid} >> ${log_file}"
    if [ "${ora_db_pdb}" != "__UNDEFINED__" ] || [ -n "${db_db_pdb:-}" ] ; then
        logMesg 0 "==== oraTNS.sh for $ora_db_pdb" I "NONE"
        /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraTNS.sh --dbservice ${ora_db_pdb} >> ${log_file}"
    fi 
fi

# wait for listner registation
logMesg 0 "==== sleep for 60 seconds to allow Listener registration" I "NONE"
/bin/sleep 60

# Install Oracle Rest Data Services (ords)
if inListC "${build_steps}" "ords"; then
    logMesg 0 "==== oraORDS.sh (ords)" I "NONE"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraORDS.sh >> ${log_file}"
fi

# Install Oracle database sample schemas (samp)
if inListC "${build_steps}" "samp"; then
    logMesg 0 "==== oraDBSamp.sh (samp)" I "NONE"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraDBSamp.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraDBSamp.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraDBSamp.sh >> ${log_file}"
fi

# configure oracle user profile (cfg)
if inListC "${build_steps}" "cfg"; then
    logMesg 0 "==== oraUsrCfg.sh (cfg)" I "NONE"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraUsrCfg.sh >> ${log_file}"
fi

echo "===============================================================" >> "${log_file}"

echo "Build started: $( /bin/last | /bin/grep reboot | /bin/tail -1 )" >> "${log_file}"
echo "Build finished: $( date )" >> "${log_file}"
# END
