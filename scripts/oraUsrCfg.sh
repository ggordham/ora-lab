#!/bin/bash

# oraUsrCfg.sh

# simple script to configure Oracle user OS environment items

# Internal settings
export SCRIPTDIR 
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraUserCfg {
  echo >&2
  echo "$SCRIPTNAME                                      " >&2
  echo "   used to configure orcle OS user for usability " >&2
  echo "   version: $SCRIPTVER                           " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]          " >&2
  echo "-h          give this help screen                " >&2
  echo "--debug     turn on debug mode                   " >&2
  echo "--test      turn on test mode, disable DBCA run  " >&2
  echo "--version | -v Show the script version           " >&2
}

#check command line options
function checkopt_oraUsrCfg {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,insecure,datadir:,dbsid:,dbtype:,dbpdb:,orahome:,dbcatemp: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraUsrCfg                          #  help
                     exit 1;;
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

  return $badopt

}

############################################################################################
# start here

OPTIONS=$@

if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

if checkopt_oraUsrCfg "$OPTIONS" ; then

    logMesg 0 "${SCRIPTNAME} start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi


    # generate SSH keys
    logMesg 0 "Generating new SSH keys for oracle user" I "NONE"
    su - oracle -c "ssh-keygen -t RSA -b 2048 -f $HOME/.ssh/id_rsa -N ''"

    logMesg 0 "Installing oracle user command aliases and path updates" I "NONE"
    # setup path in ontime profile 
    cat <<!EOP >> /home/oracle/.bash_profile
    
# adding local scripts to PATH
PATH=$PATH:/usr/local/bin
export PATH

!EOP
    
    # setup command aliases in every run rc file
    cat <<!EOA >> /home/oracle/.bashrc

# Gary favorite aliases
alias cdoh='cd \$ORACLE_HOME'

!EOA

    # Install login script
    echo "${SCRIPTDIR}/ora-lab-login.sh" >> /home/oracle/.bashrc

    # setup extra SSH keys for remote access
    ssh_keys="$( getSecret EXTRA_SSH )"
    if [ "$ssh_keys" == "__UNDEFINED__" ]; then
        logMesg 0 "No additional SSH keys to install" I "NONE"
    else
        logMesg 0 "Installing additional SSH keys" I "NONE"
        echo "${ssh_keys}" >> /home/cloud-user/.ssh/authorized_keys
        echo "${ssh_keys}" >> /home/oracle/.ssh/authorized_keys
        # check fi oracle users exists, and install extra keys
        if /usr/bin/id oracle > /dev/null 2>&1 ; then
            [ ! -d /home/oracle/.ssh ] && /bin/mkdir -p /home/oracle/.ssh
            /usr/bin/chmod 700 /home/oracle/.ssh
            /usr/bin/chown oracle /home/oracle/.ssh/authorized_keys
            /usr/bin/chgrp oinstall /home/oracle/.ssh/authorized_keys
            /usr/bin/chmod 640 /home/oracle/.ssh/authorized_keys
        fi
    fi

    logMesg 0 "${SCRIPTNAME} finished" I "NONE"
else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

# END
