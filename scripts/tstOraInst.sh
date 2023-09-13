#!/bin/bash

# tstOraInst.sh

# Internal settings
export SCRIPTDIR
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib


function run_step {
  # capture parameters 
  my_step_name=$1
  my_step_owner=$2
  my_step_script=$3
  my_log_file=$4
  my_step_options=$5

  my_step_group=$( /usr/bin/id -gn "${my_step_owner}" )

  # if running as non-root user make sure script and log have proper owner
  if [ "${my_step_owner}" != "root" ]; then
      /usr/bin/sudo sh -c "/usr/bin/chmod 666 ${my_log_file}"
      /usr/bin/sudo sh -c "/usr/bin/chown ${my_step_owner} ${my_log_file}"
      /usr/bin/sudo sh -c "/usr/bin/chmod 774 ${SCRIPTDIR}/${my_step_script}"
      /usr/bin/sudo sh -c "/usr/bin/chgrp ${my_step_group} ${SCRIPTDIR}/${my_step_script}"
  fi
  logMesg 0 "==== step ${my_step_name} script: ${my_step_script} Start " I "${my_log_file}"
  logMesg 0 "  options ${my_step_options} " I "${my_log_file}"
  /usr/bin/sudo -u "${my_step_owner}" sh -c "cd /home/${my_step_owner}; ${SCRIPTDIR}/${my_step_script} ${my_step_options} >> ${my_log_file} 2>&1"
  my_return=$?
  logMesg 0 "==== ${my_step_script} Finished.  Return code: $my_return " I "${my_log_file}"

  return $my_return
}

############################################################################################
# start here

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
ora_ver=$( cfgGet "$CONF_FILE" srvr_ora_ver )
ora_subver=$( cfgGet "$CONF_FILE" srvr_ora_subver )
stg_dir=$( cfgGet "$CONF_FILE" srvr_stg_dir )
ora_base=$( cfgGet "$CONF_FILE" srvr_ora_base )
ora_home=$( cfgGet "$CONF_FILE" srvr_ora_home )

# start with clean step status
stp_status=0

# run Linux pre-install items (pre)
if inListC "${build_steps}" "pre"; then
    options=""
    run_step pre root oraLnxPre.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# download and stage rquired software (stg)
if inListC "${build_steps}" "stg" && (( stp_status == 0 )); then
    options=""
    run_step stg root oraSwStg.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# run software install (inst)
if inListC "${build_steps}" "inst" && (( stp_status == 0 )); then
    options=""
    run_step inst root oraSwInst.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# run database creation assistant (dbca)
if inListC "${build_steps}" "dbca" && (( stp_status == 0 )); then
    options="--insecure"
    run_step dbca oracle oraDBCA.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# run database creation assistant (lsnr)
if inListC "${build_steps}" "lsnr" && (( stp_status == 0 )); then
    options=""
    run_step lsnr oracle oraLsnr.sh "${log_file}" "${options}" 
    stp_status=$?

    # create TNS entires
    ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid )
    ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb )
    logMesg 0 "==== oraTNS.sh for $ora_db_sid" I "${log_file}"
    options="--dbservice ${ora_db_sid}"
    run_step tns oracle oraTNS.sh "${log_file}" "${options}" 
    stp_status=$?
    if [ "${ora_db_pdb}" != "__UNDEFINED__" ] || [ -n "${db_db_pdb:-}" ] ; then
        options="--dbservice ${ora_db_pdb}"
        run_step tns oracle oraTNS.sh "${log_file}" "${options}" 
        stp_status=$?
    fi 

    # wait for listner registation
    logMesg 0 "==== sleep for 60 seconds to allow Listener registration" I "${log_file}"
    /bin/sleep 60
fi


# Install Oracle Rest Data Services (ords)
if inListC "${build_steps}" "ords" && (( stp_status == 0 )); then
    options=""
    run_step ords root oraORDS.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# Install Oracle database sample schemas (samp)
if inListC "${build_steps}" "samp" && (( stp_status == 0 )); then
    options=""
    run_step samp oracle oraDBSamp.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# Install Oracle RWL Load Simulator install (rwli)
if inListC "${build_steps}" "rwli" && (( stp_status == 0 )); then
    options=""
    run_step rwli root oraRWLInst.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# Setup the RWL Load Simulator in the database (rwls)
if inListC "${build_steps}" "rwls" && (( stp_status == 0 )); then
    options=""
    run_step rwlset oracle oraRWLSetup.sh "${log_file}" "${options}" 
    stp_status=$?
fi

# configure oracle user profile (cfg)
if inListC "${build_steps}" "cfg" && (( stp_status == 0 )); then
    options=""
    run_step cfg root oraUsrCfg.sh "${log_file}" "${options}" 
    stp_status=$?
fi

echo "===============================================================" >> "${log_file}"

echo "Final Build status code: $stp_status"
echo "Build started: $( /bin/last | /bin/grep reboot | /bin/tail -1 )" >> "${log_file}"
echo "Build finished: $( date )" >> "${log_file}"
# END
