define gname=idle
column global_name new_value gname
set heading off
set termout off
col global_name noprint
select UPPER(SYS_CONTEXT('USERENV','CURRENT_USER')||'['||SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'))||']'
       || '@' || 
       UPPER(sys_context('USERENV','CDB_NAME')||':'||sys_context ('USERENV', 'CON_NAME'))  AS global_name 
  FROM dual;
set sqlprompt '&gname> '
set heading on
set termout on

