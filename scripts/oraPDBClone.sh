#!/bin/bash -x 

SRC_PDB=pdb0
TARGET_PDB=$1
SRC_DB_MOUNT=/u02/oradata
TGT_DB_MOUNT=$2

ORACLE_SID=$( pgrep -fa ora_pmon |grep -v ASM | cut -d _ -f 3 )
if [ ! -z "$ORACLE_SID" ]; then
  export ORACLE_SID

  export ORAENV_ASK=NO
  source /usr/local/bin/oraenv -s

  echo "Cloning $SRC_PDB to $TARGET_PDB using target storage $TGT_DB_MOUNT"
  # setup source location
  src_loc="${SRC_DB_MOUNT}/${ORACLE_SID^^}/${SRC_PDB}"
  # create target directory 
  tgt_loc="${TGT_DB_MOUNT}/${ORACLE_SID^^}/${TARGET_PDB}"
  if [ ! -d "${tgt_loc}" ] ; then mkdir -p "${tgt_loc}" ; fi

  #  make pdb read only
  "$ORACLE_HOME"/bin/sqlplus -s /nolog <<EOF

  SET ECHO ON
  connect / as sysdba
  alter pluggable database ${SRC_PDB} close immediate;
  alter pluggable database ${SRC_PDB} open read only;

  -- Clone the PDB
  create pluggable database ${TARGET_PDB} from ${SRC_PDB}
     file_name_convert=('${src_loc}/','${tgt_loc}/');
  alter pluggable database ${TARGET_PDB} open;
  alter pluggable database ${TARGET_PDB} save state;

  -- put source PDB back 
  alter pluggable database ${SRC_PDB} close immediate;
  alter pluggable database ${SRC_PDB} open;

EOF

else
  echo "ERROR could not find running Oracle Databse"
  exit 1
fi

