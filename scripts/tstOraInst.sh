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
echo "===============================================================" >> "${log_file}"
logMesg 0 "==== Log File: ${log_file}" I "${log_file}"

# get list of steps to run
build_steps=$( cfgGet "$CONF_FILE" build_steps )
logMesg 0 "=== Build steps: $build_steps" I "${log_file}"

# Note need to add lookup for any non-defaulted values, not just known ones
disk_list=$( cfgGet "$CONF_FILE" srvr_disk_list )
ora_ver=$( cfgGet "$CONF_FILE" srvr_ora_ver )
ora_subver=$( cfgGet "$CONF_FILE" srvr_ora_subver )
stg_dir=$( cfgGet "$CONF_FILE" srvr_stg_dir )
ora_base=$( cfgGet "$CONF_FILE" srvr_ora_base )
ora_home=$( cfgGet "$CONF_FILE" srvr_ora_home )


# run Linux pre-install items (pre)
if inListC "${build_steps}" "pre"; then
    logMesg 0 "==== oraLnxPre.sh (pre)" I "${log_file}"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraLnxPre.sh --disks ${disk_list} >> ${log_file} 2>&1"
fi

# download and stage rquired software (stg)
if inListC "${build_steps}" "stg"; then
    logMesg 0 "==== oraSwStg.sh (stg)" I "${log_file}"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwStg.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file} 2>&1"
fi

# run software install (inst)
if inListC "${build_steps}" "inst"; then
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    logMesg 0 "==== oraSwInst.sh (inst)" I "${log_file}"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraSwInst.sh --oraver ${ora_ver} --orasubver ${ora_subver} --stgdir ${stg_dir} --orabase ${ora_base} --orahome ${ora_home} >> ${log_file} 2>&1"
fi

# run database creation assistant (dbca)
if inListC "${build_steps}" "dbca"; then
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    logMesg 0 "==== oraDBCA.sh (dbca)" I "${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraDBCA.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraDBCA.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraDBCA.sh --insecure >> ${log_file} 2>&1"
fi

# run database creation assistant (lsnr)
if inListC "${build_steps}" "lsnr"; then
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    logMesg 0 "==== oraLsnr.sh (lsnr)" I "${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraLsnr.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraLsnr.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraLsnr.sh >> ${log_file} 2>&1"

    # create TNS entires
    # decide on what SID or PDB to use for install
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraTNS.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraTNS.sh"
    ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid )
    ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb )
    logMesg 0 "==== oraTNS.sh for $ora_db_sid" I "${log_file}"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraTNS.sh --dbservice ${ora_db_sid} >> ${log_file} 2>&1"
    if [ "${ora_db_pdb}" != "__UNDEFINED__" ] || [ -n "${db_db_pdb:-}" ] ; then
        logMesg 0 "==== oraTNS.sh for $ora_db_pdb" I "${log_file}"
        /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraTNS.sh --dbservice ${ora_db_pdb} >> ${log_file} 2>&1"
    fi 
fi

# wait for listner registation
logMesg 0 "==== sleep for 60 seconds to allow Listener registration" I "${log_file}"
/bin/sleep 60

# Install Oracle Rest Data Services (ords)
if inListC "${build_steps}" "ords"; then
    logMesg 0 "==== oraORDS.sh (ords)" I "${log_file}"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraORDS.sh >> ${log_file} 2>&1"
fi

# Install Oracle database sample schemas (samp)
if inListC "${build_steps}" "samp"; then
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    logMesg 0 "==== oraDBSamp.sh (samp)" I "${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraDBSamp.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraDBSamp.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraDBSamp.sh >> ${log_file} 2>&1"
fi

# Install Oracle RWL Load Simulator (rwli)
if inListC "${build_steps}" "samp"; then
    logMesg 0 "==== oraRWLInst.sh (rwli)" I "${log_file}"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraRWLInst.sh >> ${log_file} 2>&1"
fi

# Setup the RWL Load Simulator in the database (rwlset)
if inListC "${build_steps}" "rwlset"; then
    /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chown oracle ${log_file}"
    logMesg 0 "==== oraRWLSetup.sh (rwlset)" I "${log_file}"
    /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/oraRWLSetup.sh"
    /usr/bin/sudo sh -c "/usr/bin/chgrp oinstall ${SCRIPTDIR}/oraRWLSetup.sh"
    /usr/bin/sudo -u oracle sh -c "${SCRIPTDIR}/oraRWLSetup.sh >> ${log_file} 2>&1"
fi

# configure oracle user profile (cfg)
if inListC "${build_steps}" "cfg"; then
    logMesg 0 "==== oraUsrCfg.sh (cfg)" I "${log_file}"
    /usr/bin/sudo sh -c "${SCRIPTDIR}/oraUsrCfg.sh >> ${log_file} 2>&1"
fi

echo "===============================================================" >> "${log_file}"

echo "Build started: $( /bin/last | /bin/grep reboot | /bin/tail -1 )" >> "${log_file}"
echo "Build finished: $( date )" >> "${log_file}"
# END
