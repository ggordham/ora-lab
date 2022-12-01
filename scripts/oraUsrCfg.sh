#!/bin/bash

# oraUsrCfg.sh

# simple script to configure Oracle user OS environment items

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

logMesg 0 "${SCRIPTNAME} start" I "NONE"

# generate SSH keys
su - oracle -c ssh-keygen -t RSA -b 2048 -N ''

# setup path in ontime profile 
cat <<!EOP >> /home/oracle/.bash_profile

# adding local scripts to PATH
PATH=$PATH:/usr/local/bin
export PATH

!EOP

# setup command aliases in every run rc file
cat <<!EOP >> /home/oracle/.bashrcQ

# Gary favorite aliases
alias cdoh='cd $ORACLE_HOME'

!EOP

logMesg 0 "${SCRIPTNAME} finished" I "NONE"

#END
