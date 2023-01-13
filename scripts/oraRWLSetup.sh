#!/bin/bash
#
# oraRWLSetup.sh

rwl_password=xxxx
my_project=pdb1
my_db=pdb1
my_cdb=t1db

rwl_dir=/u01/app/oracle/rwloadsim
rwl_output=/u01/app/oracle/admin/rwlout
rwl_password=xxxx

export ORACLE_SID=${my_cdb}
export ORAENV_ASK=NO
source /usr/local/bin/oraenv

source "${rwl_output}/workdir/${my_project}/${my_project}.env"

temp_dir=/home/oracle/temp

[ ! -d "${temp_dir}" ] && mkdir "${temp_dir}"
cp "${rwl_dir}/admin/rwlschema.sql" "${temp_dir}"

sed -i "s/{password}/${rwl_password}/" "${temp_dir}"/rwlschema.sql

connect / as sysdb

@${temp_dir}/rwlschema.sql

CREATE TABLESPACE DATA DATAFILE '/u02/oradata/T1DB/pdb1/data01.dbf' SIZE 10G;

connect rwloadsim/${rwl_password}@${my_db}

@${rwl_dir}/rwloadsim.sql
@${rwl_dir}/rwlviews.sql

# verify the following items:
#  directory structure
oltpverify -d > "${temp_dir}/oltpverify_dir.log"
if grep -qE "fixed|writable" "${temp_dir}/oltpverify_dir.log"; then
    echo "ERROR - directory sturcture for OLTP could not be verified!"
    echo "ERROR - check log file: ${temp_dir}/oltpverify_dir.log"
    exit 1
fi

# verify test OLTP schemas and DB connections
# example response where everything is good
# repository:ok systemdb:ok cruserdb:ok runuser:ok
oltpverify -a > "${temp_dir}/oltpverify_db.log"
if grep -q fail "${temp_dir}/oltpverify_db.log"; then
    echo "ERROR - issue with database connection or setup"
    echo "ERROR - check log file: ${temp_dir}/oltpverify_db.log"
    tail -1 "${temp_dir}/oltpverify_db.log"
else  
    echo "INFO - DB test status: "
    tail -1 "${temp_dir}/oltpverify_db.log"
fi


#   system access to test database
#   repository access for RWL
# look for the word fail:
#   repository:fail 
# oltpverify -s
# oltpverify -r



# Create the OLTP schema in the test database
#   if you have issues you can drop the OLT test schemas
#   oltpdrop
oltpcreate > "${temp_dir}/oltpcreate.log"
if grep -i error "${temp_dir}/oltpcreate.log"; then
    echo "ERROR - creating OLTP schemas and loading data"
    echo "ERROR - check log file: ${temp_dir}/oltpcreate.log"
    echo "ERROR - oltpdrop is being run to prepare for re-run"
    oltpdrop > "${temp_dir}/oltpdrop.log"
    exit 1
else
    echo "INFO - no errors detected in OLTP load"
fi


