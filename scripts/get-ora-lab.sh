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
        /usr/bin/sudo /usr/bin/dnf -y install tar
    elif [ -x /usr/bin/yum ]; then
        /usr/bin/sudo /usr/bin/yum -y install tar
    else 
        echo "ERROR: TAR not installed and package manager not found"
        exit 1
    fi
fi

# make the target directory for ora-lab
[[ ! -d "${target_path}" ]] && sudo /usr/bin/mkdir "${target_path}"
sudo /usr/bin/chown cloud-user:cloud-user "${target_path}"

# download the ora-lab scripts
/usr/bin/curl -L ${repo_url}/tarball/main | tar xz -C "${target_path}" --strip=1 "${package_root}-???????/${target}"

# check if cloud-init is finished then reboot
while [ ! "$( trim "$( /usr/bin/sudo /usr/bin/cloud-init status | /usr/bin/cut -d: -f2 )" )" == "done" ]; do
    echo "Waiting for Cloud init to complete, sleeping 30 seconds"
    sleep 30
done

# reboot after cloud-init is finished
#  Be sure to exit 0 for terraform to get good status
( /usr/bin/sleep 5 && /usr/bin/sudo /usr/sbin/reboot ) &
exit 0

# END 
