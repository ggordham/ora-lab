#!/bin/bash
#
# oraRWLRun.sh

my_project=pdb1
my_db=pdb1
my_cdb=t1db

rwl_output=/u01/app/oracle/admin/rwlout

export ORACLE_SID=${my_cdb}
export ORAENV_ASK=NO
source /usr/local/bin/oraenv

source "${rwl_output}/workdir/${my_project}/${my_project}.env"

temp_dir=/home/oracle/temp
log_file=${temp_dir}/oltprun-$( date +%Y%m%d-%H%M%S ).log

echo "INFO - Starting OLTP run on DB ${my_db}"
echo "INFO - Log file at: ${log_file}"

oltpcore -r 195 > "${log_file}"

echo "OLTP run completed, check log file at: ${log_file}"

