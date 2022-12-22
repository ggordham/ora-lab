#!/bin/bash

# oraDBSamp.sh

# install the Oracle database sample schemas

# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

env_name=t1db
db_name=pdb1

stg_dir=/u01/app/oracle/stage
samp_schema_url=https://github.com/oracle/db-sample-schemas
app_dir=examples
tgt_dir="${stg_dir}/${app_dir}"

sys_password=xxxx
system_password=xxxx
samp_password=xxxx

samp_tablespace=USERS
samp_temp=TEMP

connect_string=localhost:1521/${db_name}

# setup Oracle environment
export ORACLE_SID=$env_name
export ORAENV_ASK=NO

source /usr/local/bin/oraenv -s


# Make sure the staging directory is created
[ ! -d "${tgt_dir}" ] && mkdir -p "${tgt_dir}"

# download the source files
curl -L "${samp_schema_url}/tarball/main" | tar xz --strip=1 -C "${tgt_dir}" 

# update path in scripts to target directory
find "${tgt_dir}" -type f \( -name "*.sql" -o -name "*.dat" \) -exec sed -i "s#__SUB__CWD__#${tgt_dir}#g" {} \;

cd "${tgt_dir}" || echo "Error, could not find directory: ${tgt_dir}"

"${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect system/${system_password}@${connect_string}

WHENEVER sqlerror CONTINUE;

@mksample ${system_password} ${sys_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_password} ${samp_tablespace} ${samp_temp} ${tgt_dir}/log ${connect_string}

!EOF
return_code=$?
# lets see if there was an error, and clean up so we can re-run
if (( return_code > 0 )); then 
    echo "sample schema SQLPLUS return code: $return_code"
    /usr/bin/rm -rf "${tgt_dir}"
    exit ${return_code}
fi

# install the customer order schema
cd "${tgt_dir}/customer_orders" || echo "Error, could not find directory: ${tgt_dir}/customer_orders"

"${ORACLE_HOME}"/bin/sqlplus /nolog << !EOF

SET ECHO ON
WHENEVER sqlerror EXIT sql.sqlcode;

connect system/${system_password}@${connect_string}

WHENEVER sqlerror CONTINUE;
@co_main ${samp_password} ${connect_string} ${samp_tablespace} ${samp_temp}

!EOF
return_code=$?

echo "customer orders SQLPLUS return code: $return_code"
exit ${return_code}

# END 
