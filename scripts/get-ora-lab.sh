#!/bin/bash
#
# get-ora-lab.sh
#
# Very simple script to call during VM build to pull down the required
#  ora-lab scripts for a VM

repo_url=https://github.com/ggordham/ora-lab
package_root=ggordham-ora-lab
target=scripts
target_path=/opt/ora-lab

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

/usr/bin/curl -L ${repo_url}/tarball/main | tar xz -C "${target_path}" --strip=1 "${package_root}-???????/${target}"

