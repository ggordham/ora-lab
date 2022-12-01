#!/bin/bash
#
# get-ora-lab.sh
#
# Very simple script to call during VM build to pull down the required
#  ora-lab scripts for a VM
# Script is stand alone so some redundancy here to make work in place

repo_url=https://github.com/ggordham/ora-lab
package_root=ggordham-ora-lab
target=scripts
target_path=/opt/ora-lab
log_file=/tmp/get-ora-lab.log

trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Verify tar RPM is installed
if ! rpm -q --quiet tar; then
    if [ -x /usr/bin/dnf ]; then 
        /usr/bin/sudo /usr/bin/dnf -y install tar | /usr/bin/tee -a "${log_file}"
    elif [ -x /usr/bin/yum ]; then
        /usr/bin/sudo /usr/bin/yum -y install tar | /usr/bin/tee -a "${log_file}"
    else 
        echo "ERROR: TAR not installed and package manager not found"
        exit 1
    fi
fi

# make the target directory for ora-lab
[[ ! -d "${target_path}" ]] && sudo /usr/bin/mkdir "${target_path}"
sudo /usr/bin/chown cloud-user:cloud-user "${target_path}"

# download the ora-lab scripts
/usr/bin/curl -L ${repo_url}/tarball/main | tar xz -C "${target_path}" --strip=1 "${package_root}-???????/${target}"  | /usr/bin/tee -a "${log_file}"
/usr/bin/find ${target_path} -name \*.sh -exec /usr/bin/chmod 754 {} \;

# check if cloud-init is finished then reboot
while [ ! "$( trim "$( /usr/bin/sudo /usr/bin/cloud-init status | /usr/bin/cut -d: -f2 )" )" == "done" ]; do
    echo "Waiting for Cloud init to complete, sleeping 30 seconds" | /usr/bin/tee -a "${log_file}"
    sleep 30
done

# install the ora-lab run script for after reboot
${target_path}/scripts/runonce.sh "${target_path}/scripts/tstOraInst.sh"

# reboot after cloud-init is finished
#  Be sure to exit 0 for terraform to get good status
echo "initiating reboot $( date )" >> "${log_file}"
nohup /bin/bash -c "/usr/bin/sleep 40 && /usr/bin/sudo /usr/sbin/reboot" &
jobs | /usr/bin/tee -a "${log_file}"
echo "Exiting  $( date )" >> "${log_file}"
exit 0

# END 
