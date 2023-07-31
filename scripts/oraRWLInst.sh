#!/bin/bash

# oraRWLInst.sh - install the RWP*Load Simulator
#   More information at: https://github.com/oracle/rwloadsim

# https://github.com/oracle/rwloadsim
#
# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
# shellcheck disable=SC1090
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraRWLInst {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   used to run RWP*Load Simulator OLTP .       " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]        " >&2
  echo "-h          give this help screen               " >&2
  echo "--url     [Full download URL for software]      " >&2
  echo "--dir     [Install direcotry]                   " >&2
  echo "--outdir  [RWL output directory]                " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode, disable DBCA run " >&2
  echo "--version | -v Show the script version          " >&2
  echo "                                                " >&2
  echo " Note: outdir is also location of RWL project   " >&2
}

#check command line options
function checkopt_oraRWLInst {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,url:,dir:,outdir: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraRWLRun                        #  help
                     exit 1;;
          "--url") rwl_src_url="$2"
                     shift 2;;
          "--dir") rwl_dir="$2"
                     shift 2;;
          "--outdir") rwl_outdir="$2"
                     shift 2;;
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

# shellcheck disable=SC2124
OPTIONS=$@

# verify that we are root to run this script
if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

if checkopt_oraRWLInst "$OPTIONS" ; then

    # check if a oracle_db_sid and other settings, otherwise lookup default setting
    if [ -z "${ora_db_sid:-}" ]; then ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid ); fi
    if [ -z "${ora_db_pdb:-}" ]; then ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb ); fi
    if [ -z "${rwl_dir:-}" ]; then rwl_dir=$( cfgGet "$CONF_FILE" rwl_dir ); fi
    if [ -z "${rwl_outdir:-}" ]; then rwl_outdir=$( cfgGet "$CONF_FILE" rwl_outdir ); fi
    if [ -z "${rwl_proj:-}" ]; then rwl_proj=$( cfgGet "$CONF_FILE" rwl_proj ); fi

    if [ -z "${rwl_src_url:-}" ]; then rwl_src_url=$( cfgGet "$ORA_CONF_FILE" rwl_proj ); fi

    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_sid: $ora_db_sid" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_db_pdb: $ora_db_pdb" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_proj: $rwl_proj" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_dir: $rwl_outdir" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_outdir: $rwl_outdir" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "rwl_src_url: $rwl_src_url" I "NONE" ; fi
    
    # Lookup password for database
    secret_name="db_all_${ora_db_sid}"
    db_password=$( getSecret "${secret_name}" )
    if [ "$db_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for DB, secret: $secret_name" E "NONE" 
        exit 1
    fi

    # Lookup password for RWL schemas
    secret_name="db_rwl_${ora_db_sid}"
    rwl_password=$( getSecret "${secret_name}" )
    if [ "$rwl_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for RWL schemas, secret: $secret_name" E "NONE" 
        exit 1
    fi

    rwl_src_file=$( /usr/bin/basename "${rwl_src_url}" )
    db_url="//$( hostname -f ):1521/${ora_db_pdb}"
    cdb_url="//$( hostname -f ):1521/${ora_db_sid}"
    
    # install required GNUPlot software
    yum -y install gnuplot
    
    # install the RWL binaries
    mkdir -p "${rwl_dir}"
    wget "${rwl_src_url}" 
    tar -xzf "${rwl_src_file}" -C $"${rwl_dir}"
    
    # setup the location files
    rwl_results=${rwl_outdir}/results/${rwl_proj}
    rwl_out=${rwl_outdir}/html/${rwl_proj}
    rwl_work=${rwl_outdir}/workdir/${rwl_proj}
    
    mkdir -p "${rwl_results}"
    mkdir -p "${rwl_out}"
    mkdir -p "${rwl_work}"
    
    # setup env file
    rwl_env="${rwl_work}/${rwl_proj}.env"

    echo "# rwloadsim config file for OLTP "   >  "${rwl_env}"
    echo "#  Generated by oraRWL.sh script  "   >> "${rwl_env}"
    echo "export RWLOLTP_NAME=${rwl_proj} "  >> "${rwl_env}"
    echo "export RWLOADSIM_PATH=${rwl_work} "  >> "${rwl_env}"
    echo "#  Adding RWLoadSim into path    "   >> "${rwl_env}"
    echo "export PATH=\$PATH:${rwl_dir}/bin "  >> "${rwl_env}"
    echo "#  For -g option to set gnuplot geometry"   >> "${rwl_env}"
    echo "export RWLOLTP_GNUPLOT1='-geometry 640x350+0+0'"   >> "${rwl_env}"
    echo "export RWLOLTP_GNUPLOT2='-geometry 640x350+0+400'"   >> "${rwl_env}"
    
    # cp "${rwl_dir}/oltp/oltp.rwl" "${rwl_work}/${rwl_proj}.rwl"

    rwl_rwl="${rwl_work}/${rwl_proj}.rwl"
    echo "# rwloadsim rwl file for OLTP           "                >  "${rwl_rwl}"
    echo "#  Generated by oraWL.sh script         "                >> "${rwl_rwl}"
    echo "# name of the directory where awr, html, graphs"         >> "${rwl_rwl}"
    echo "awrdirectory := \"${rwl_out}\";"                         >> "${rwl_rwl}"
    echo "# name of the results directory"                         >> "${rwl_rwl}"
    echo "resultsdir:=\"${rwl_results}\";"                         >> "${rwl_rwl}"
    echo "# connect strings either in URL or tnsnames entry that will be used when the  oltp  workload  is  executing"   >> "${rwl_rwl}"
    echo "normal_connect := \"${db_url}\";"   >> "${rwl_rwl}"
    echo "pool_connect   := \"${db_url}\";"   >> "${rwl_rwl}"
    echo "batch_connect  := \"${db_url}\";"   >> "${rwl_rwl}"
    echo "# used when schemas are created and filled with data"   >> "${rwl_rwl}"
    echo "cruser_connect := \"${db_url}\";"   >> "${rwl_rwl}"
    echo "cruser_username := \"system\";"   >> "${rwl_rwl}"
    echo "cruser_password := \"${db_password}\";"   >> "${rwl_rwl}"
    echo "# used during actual execution of your runs to primarily run queries against v$ tables etc" >> "${rwl_rwl}"
    echo "system_connect := \"${db_url}\";"   >> "${rwl_rwl}"
    echo "system_username := \"system\";"   >> "${rwl_rwl}"
    echo "db_password := \"${db_password}\";"   >> "${rwl_rwl}"
    echo "# Generate AWR reports from root container"           >> "${rwl_rwl}"
    echo "sysawr_connect := \"${cdb_url}\";"   >> "${rwl_rwl}"
    echo "sysawr_username := \"system\";"   >> "${rwl_rwl}"
    echo "sysawr_password := \"${db_password}\";"   >> "${rwl_rwl}"
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

    # make sure the oracle user owns all the files
    chown -R oracle:oinstall "${rwl_dir}"
    chown -R oracle:oinstall "${rwl_outdir}"

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

#END
