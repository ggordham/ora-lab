#!/bin/bash
# shellcheck disable=SC2024
#
# get-ora-lab.sh
#
# Very simple script to call during VM build to pull down the required
#  ora-lab scripts for a VM
# Script is stand alone so some redundancy here to make work in place
# version 1.0

# Internal settings
SCRIPTVER=1.1
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")

repo_url=https://github.com/ggordham/ora-lab
package_root=ggordham-ora-lab
target=scripts
target_path=/opt/ora-lab
log_file=/tmp/get-ora-lab-$( date +%Y%m%d-%H%M%S ).log
cur_user=$( /usr/bin/id -un )
cur_group=$( /usr/bin/id -gn )
refresh=FALSE
ora_scrpt_list="oraDBCA.sh oraRWLRun.sh oraRWLSetup.sh oraTNS.sh oraLsnr.sh oraDBSamp.sh oraTools.sh oraPDBClone.sh"

# retun command line help information
function help_get-ora-lab {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   Download ora-lab scripts and initiate install " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
  echo "--refresh   download scripts only               " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode                   " >&2
  echo "--version | -v Show the script version          " >&2
}

# simple trim white space function
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Process command line options
# shellcheck disable=SC2068
my_opts=$(getopt -o hv --long debug,test,version,refresh -n "$SCRIPTNAME" -- $@)
if (( $? > 0 )); then
   (( badopt=1 ))
else
    eval set -- "$my_opts"
    while true; do
        case $1 in
            "-h") help_get-ora-lab                          #  help
                  exit 1;;
             "--refresh") refresh=TRUE                    # test mode
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

if (( badopt > 0 )); then 
    echo "ERROR bad command line option!"
    exit 1
fi

############################################################################################
# start here

echo "===== get-ora-lab.sh Starting" | /usr/bin/tee -a "${log_file}"
echo "  running as user: $cur_user " | /usr/bin/tee -a "${log_file}" 
echo "  running as group: $cur_group " | /usr/bin/tee -a "${log_file}"

if [ "$DEBUG" == "TRUE" ]; then echo "DEBUG Mode Enabled!" | /usr/bin/tee -a "${log_file}"; fi
if [ "$TEST" == "TRUE" ]; then echo "TEST Mode Enabled, commands will not be run." | /usr/bin/tee -a "${log_file}"; fi
if [ "$refresh" == "TRUE" ]; then echo "refresh Mode Enabled, will only download scripts." | /usr/bin/tee -a "${log_file}"; fi

# Verify tar RPM is installed
if ! /usr/bin/rpm -q --quiet tar; then
    if [ -x /usr/bin/dnf ]; then 
        /usr/bin/sudo /usr/bin/dnf -y install tar >> "${log_file}" 2>&1
    elif [ -x /usr/bin/yum ]; then
        /usr/bin/sudo /usr/bin/yum -y install tar >> "${log_file}" 2>&1
    else 
        echo "ERROR: TAR not installed and package manager not found" | /usr/bin/tee -a "${log_file}"
        exit 1
    fi
fi

# make the target directory for ora-lab
echo "  Making target path: $target_path" | /usr/bin/tee -a "${log_file}"
[[ ! -d "${target_path}" ]] && sudo /usr/bin/mkdir "${target_path}" >> "${log_file}" 2>&1
sudo /usr/bin/chown "${cur_user}" "${target_path}" >> "${log_file}" 2>&1
sudo /usr/bin/chgrp "${cur_group}" "${target_path}" >> "${log_file}" 2>&1

# download the ora-lab scripts
echo "  Downloading ora-lab scripts from: ${repo_url}/scripts/tstOraInst.sh" | /usr/bin/tee -a "${log_file}"
if [ "$TEST" == "TRUE" ]; then
    echo "Test mode, not running: /usr/bin/curl -L ${repo_url}/tarball/main | tar xz -C ${target_path} --strip=1 ${package_root}-???????/${target}" | /usr/bin/tee -a "${log_file}"
else
    /usr/bin/curl -L ${repo_url}/tarball/main | tar xz -C "${target_path}" --strip=1 "${package_root}-???????/${target}"  | /usr/bin/tee -a "${log_file}"
    /usr/bin/find ${target_path} -name \*.sh -exec /usr/bin/chmod 754 {} \; >> "${log_file}" 2>&1

    # fix ownership of scripts that should have oracle user access
    for scrpt in ${ora_scrpt_list}; do
      /usr/bin/find ${target_path} -name "${scrpt}" -exec /usr/bin/chgrp 54321 {} \; >> "${log_file}" 2>&1
    done
fi

# if we are not in refresh mode setup the reboot process
if [ "${refresh}" == "FALSE" ]; then
    echo "Setting up automated reboot and install." | /usr/bin/tee -a "${log_file}"
    # check if cloud-init is finished then reboot
    while [ ! "$( trim "$( /usr/bin/sudo /usr/bin/cloud-init status | /usr/bin/cut -d: -f2 )" )" == "done" ]; do
        echo "  Waiting for Cloud init to complete, sleeping 30 seconds" | /usr/bin/tee -a "${log_file}"
        sleep 30
    done
    
    # install the ora-lab run script for after reboot
    echo "Installing runonce script: ${target_path}/scripts/tstOraInst.sh" | /usr/bin/tee -a "${log_file}"
    if [ "$TEST" == "TRUE" ]; then
        echo "Test mode, not running: ${target_path}/scripts/runonce.sh ${target_path}/scripts/tstOraInst.sh" | /usr/bin/tee -a "${log_file}"
    else
        "${target_path}"/scripts/runonce.sh "${target_path}/scripts/tstOraInst.sh" >> "${log_file}" 2>&1 
    fi
    
    # reboot after cloud-init is finished
    #  Be sure to exit 0 for terraform to get good status
    echo "initiating reboot $( date )" | /usr/bin/tee -a "${log_file}"
    if [ "$TEST" == "TRUE" ]; then
        echo "Test mode, not running: /usr/bin/nohup /bin/bash -c /usr/bin/sleep 40 && /usr/bin/sudo /usr/sbin/reboot" | /usr/bin/tee -a "${log_file}"
    else
        /usr/bin/nohup /bin/bash -c "/usr/bin/sleep 40 && /usr/bin/sudo /usr/sbin/reboot" > /tmp/ora-lab-reboot.log &
        jobs | /usr/bin/tee -a "${log_file}"
    fi
fi

echo "Exiting  $( date )" | /usr/bin/tee -a "${log_file}"
echo "===== get-ora-lab.sh Finished" | /usr/bin/tee -a "${log_file}"
exit 0

# END 
