#!/bin/bash

# oraRWL.sh

# https://github.com/oracle/rwloadsim

rwl_dir=/u01/app/oracle/rwloadsim
src_file=rwloadsim-linux-x86_64-bin-3.0.4.tgz
rwl_output=/u01/app/oracle/admin/rwlout

my_project=pdb1
my_db=pdb1
my_cdb=t1db

system_password=xxxx
rwl_password=xxxx

db_url="//$( hostname -f ):1521/${my_db}"
cdb_url="//$( hostname -f ):1521/${my_cdb}"


yum -y install gnuplot

mkdir -p "${rwl_dir}"
tar -xvzf "${src_file}" -C $"{rwl_dir}"

mkdir -p "${rwl_output}/results/${my_project}"
mkdir -p "${rwl_output}/html/${my_project}"
mkdir -p "${rwl_output}/workdir/${my_project}"

# setup env file
rwl_env="${rwl_output}/workdir/${my_project}.env"
# cp "${rwl_dir}/oltp/oltp.env" "${rwl_output}/workdir/${my_project}.env"
echo "# rwloadsim config file for OLTP "   >  "${rwl_env}"
echo "#  Generated by oraWL.sh script  "   >> "${rwl_env}"
echo "export RWLOLTP_NAME=${my_project} "  >> "${rwl_env}"

# cp "${rwl_dir}/oltp/oltp.rwl" "${rwl_output}/workdir/${my_project}.rwl"

rwl_rwl="${rwl_output}/workdir/${my_project}.rwl"
echo "# rwloadsim rwl file for OLTP           "                >  "${rwl_rwl}"
echo "#  Generated by oraWL.sh script         "                >> "${rwl_rwl}"
echo "# name of the directory where awr, html, graphs"         >> "${rwl_rwl}"
echo "awrdirectory := \"${rwl_output}/html/${my_project}\";"   >> "${rwl_rwl}"
echo "# name of the results directory"                         >> "${rwl_rwl}"
echo "resultsdir:=\"${rwl_output}/results/${my_project}\";"   >> "${rwl_rwl}"
echo "# connect strings either in URL or tnsnames entry that will be used when the  oltp  workload  is  executing"   >> "${rwl_rwl}"
echo "normal_connect := \"${db_url}\";"   >> "${rwl_rwl}"
echo "pool_connect   := \"${db_url}\";"   >> "${rwl_rwl}"
echo "batch_connect  := \"${db_url}\";"   >> "${rwl_rwl}"
echo "# used when schemas are created and filled with data"   >> "${rwl_rwl}"
echo "cruser_connect := \"${db_url}\";"   >> "${rwl_rwl}"
echo "cruser_username := \"system\";"   >> "${rwl_rwl}"
echo "cruser_password := \"${system_password}\";"   >> "${rwl_rwl}"
echo "# used during actual execution of your runs to primarily run queries against v$ tables etc" >> "${rwl_rwl}"
echo "system_connect := \"${db_url}\";"   >> "${rwl_rwl}"
echo "system_username := \"system\";"   >> "${rwl_rwl}"
echo "system_password := \"${system_password}\";"   >> "${rwl_rwl}"
echo "# Generate AWR reports from root container"           >> "${rwl_rwl}"
echo "sysawr_connect := \"${cdb_url}\";"   >> "${rwl_rwl}"
echo "sysawr_username := \"system\";"   >> "${rwl_rwl}"
echo "sysawr_password := \"${system_password}\";"   >> "${rwl_rwl}"
echo "# set the connection information for rwl repository"  >> "${rwl_rwl}"
echo "results_in_test := 1; "   >> "${rwl_rwl}"
echo "results_username := \"RWLOADSIM\";"   >> "${rwl_rwl}"
echo "results_password := \"${rwl_password}\";"   >> "${rwl_rwl}"
echo "results_connect := \"${db_url}\";"   >> "${rwl_rwl}"
echo "# where to find the files with ddl"   >> "${rwl_rwl}"
echo "rwloadsimdir := \"${rwl_dir}/admin\";"   >> "${rwl_rwl}"

echo "# Test users for the OLTP run"               >> "${rwl_rwl}"
echo "default_tablespace := \"data\";"             >> "${rwl_rwl}" 
echo "rwl_aw1_username := \"RWLAW1\";"             >> "${rwl_rwl}"
echo "rwl_aw1_password := \"${rwl_password}\";"    >> "${rwl_rwl}"
echo "rwl_aw2_username := \"RWLAW2\";"             >> "${rwl_rwl}"
echo "rwl_aw2_password := \"${rwl_password}\";"    >> "${rwl_rwl}"
echo "rwl_oe_username := \"RWLOE\";"               >> "${rwl_rwl}"
echo "rwl_oe_password := \"${rwl_password}\";"     >> "${rwl_rwl}"
echo "rwl_run1_username := \"RWLRUN1\"; "          >> "${rwl_rwl}"
echo "rwl_run1_password := \"${rwl_password}\";"   >> "${rwl_rwl}"
echo "rwl_run2_username := \"RWLRUN2\";"           >> "${rwl_rwl}"
echo "rwl_run2_password := \"${rwl_password}\";"   >> "${rwl_rwl}"
echo "rwl_run_like := \"RWLRUN_\";"                >> "${rwl_rwl}"
echo "rwl_title := \"rwl oltp development test\";" >> "${rwl_rwl}"
echo "gnuplotjs := \"/usr/share/gnuplot/4.6/js\";" >> "${rwl_rwl}"
echo "rwl_heading := \"heading for daily oltp\";"  >> "${rwl_rwl}"
echo "rwl_daily_html := \"daily.html\";"           >> "${rwl_rwl}"

