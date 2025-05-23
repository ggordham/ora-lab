#!/bin/bash

# oraORDS.sh

# select ords.installed_version from dual;
#
# Internal settings
SCRIPTVER=1.0
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/oralab.shlib

# retun command line help information
function help_oraORDS {
  echo >&2
  echo "$SCRIPTNAME                                    " >&2
  echo "   Install and setup Oracle Rest Data Services " >&2
  echo "   version: $SCRIPTVER                         " >&2
  echo >&2
  echo "Usage: $SCRIPTNAME [-h --debug --test ]         " >&2
  echo "-h          give this help screen               " >&2
  echo "--ordspath  [ORDS install path]                 " >&2
  echo "--ordsadmin [ORDS admin path]                   " >&2
  echo "--ordssrc   [ORDS Source zip file]              " >&2
  echo "--ordsport  [ORDS port]                         " >&2
  echo "--pdbonly   install ORDS in PDB only not CDB    " >&2
  echo "--httpsno   disable HTTPS configuration         " >&2
  echo "--debug     turn on debug mode                  " >&2
  echo "--test      turn on test mode                   " >&2
  echo "--version | -v Show the script version          " >&2
}

#check command line options
function checkopt_oraORDS {

    #set defaults
    DEBUG=FALSE
    TEST=FALSE
    HTTPS=TRUE
    typeset -i badopt=0

    # shellcheck disable=SC2068
    my_opts=$(getopt -o hv --long debug,test,version,pdbonly,httpsno,ordspath:,ordsadmin:,ordssrc:,ordsport: -n "$SCRIPTNAME" -- $@)
    if (( $? > 0 )); then
        (( badopt=1 ))
    else
        eval set -- "$my_opts"
        while true; do
            case $1 in
               "-h") help_oraORDS                          #  help
                     exit 1;;
          "--ordsport") ords_port="$2"
                     shift 2;;
          "--odssrc") ords_src="$2"
                     shift 2;;
          "--odsadmin") ords_admin="$2"
                     shift 2;;
          "--odspath") ords_path="$2"
                     shift 2;;
          "--pdbonly") srvr_ords_pdbonly=TRUE 
                     shift ;;
          "--httpsno") HTTPS=FALSE 
                     shift ;;
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

create_target_dirs () {

    # create the target directories
    [[ ! -d "${ords_path}" ]] && mkdir -p "${ords_path}"
    [[ ! -d "${ords_admin}" ]] && mkdir -p "${ords_admin}"
    [[ ! -d "${ORDS_CONFIG}" ]] && mkdir -p "${ORDS_CONFIG}"
    [[ ! -d "${ords_logs}" ]] && mkdir -p "${ords_logs}"
    /usr/bin/chown oracle:oinstall "${ords_path}"
    /usr/bin/chown oracle:oinstall "${ords_admin}"
    /usr/bin/chown oracle:oinstall "${ORDS_CONFIG}"
    /usr/bin/chown oracle:oinstall "${ords_logs}"

}

load_ords_url () {

    local my_ords_latest
    local my_ords_file

    my_ords_latest=$( cfgGet "$CONF_FILE" ords_latest )
    my_ords_file="$( /bin/basename "${my_ords_latest}" )"
    # create install location
    create_target_dirs
    # Download the latest version
    cd "${ords_path}" || logMesg 1 "Could not find install path: ${ords_path}" E "NONE" || exit 1
    /bin/curl -O -L "${my_ords_latest}"
    cd - || exit 1

    if [ -f "${ords_path}/${my_ords_file}" ]; then
        /usr/bin/su oracle -c "/usr/bin/unzip -q -o -d ${ords_path} ${ords_path}/${my_ords_file}"
    else
        echo "ERROR! could not download ORDS install file at: ${my_ords_latest}"
        exit 1
    fi
      
  
}

load_ords_file () {
    # check if the ORDS install file is there
    if [ -f "${ords_src}" ]; then
        create_target_dirs
        # load the ORDS software
        /usr/bin/su oracle -c "/usr/bin/unzip -q -o -d ${ords_path} ${ords_src}"
    else
        echo "ERROR! could not find ORDS install file at: ${ords_src}"
        exit 1
    fi
        
} 

load_ords_repo () {

    local my_os_ver
    local my_repo_url
    local my_ords_repo
    my_ords_repo=$( cfgGet "$CONF_FILE" ords_repo )

    # OS version
    my_os_ver=$( /bin/grep '^VERSION_ID' /etc/os-release | /bin/tr -d '"' | /bin/cut -d . -f 1 | /bin/cut -d = -f 2 )
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "Detected OS Version: $my_os_ver" I "NONE" ; fi
 
    # Fix repo URL for OS version
    my_repo_url=${ords_repo/OLX/OL${my_os_ver}}

    # load ORDS from repo
    /usr/bin/yum-config-manager --add-repo="${my_repo_url}"
    /usr/bin/yum install ords
}
############################################################################################
# start here

# verify that we are root to run this script
if [ "x$USER" != "xroot" ];then logMesg 1 "You must be logged in as root to run this script" E "NONE"; exit 1; fi

OPTIONS=$@

if checkopt_oraORDS "$OPTIONS" ; then

    logMesg 0 "${SCRIPTNAME} start" I "NONE"
    if [ "$DEBUG" == "TRUE" ]; then logMesg 0 "DEBUG Mode Enabled!" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "TEST Mode Enabled, commands will not be run." I "NONE" ; fi

    # check if an command line paramters were passed, otherwise load defaults
    
    if [ -z "${ords_path:-}" ]; then ords_path=$( cfgGetD "$CONF_FILE" srvr_ords_path "$ORA_CONF_FILE" ords_path ); fi
    if [ -z "${ords_src:-}" ]; then ords_src=$( cfgGetD "$CONF_FILE" srvr_ords_src "$ORA_CONF_FILE" ords_src ); fi
    if [ -z "${ords_java:-}" ]; then ords_java=$( cfgGetD "$CONF_FILE" srvr_ords_java "$ORA_CONF_FILE" ords_java ); fi
    if [ -z "${ords_addrpm:-}" ]; then ords_addrpm=$( cfgGetD "$CONF_FILE" srvr_ords_addrpm "$ORA_CONF_FILE" ords_addrpm ); fi
    if [ -z "${ords_port:-}" ]; then ords_port=$( cfgGetD "$CONF_FILE" srvr_ords_port "$ORA_CONF_FILE" ords_port ); fi
    if [ -z "${ords_admin:-}" ]; then ords_admin=$( cfgGetD "$CONF_FILE" srvr_ords_admin "$ORA_CONF_FILE" ords_admin ); fi
    if [ -z "${ords_load_from:-}" ]; then ords_load_from=$( cfgGetD "$CONF_FILE" srvr_ords_load_from "$ORA_CONF_FILE" ords_load_from ); fi

    # output some test information
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_path: $ords_path" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_src: $ords_src" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_java: $ords_java" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_addrpm: $ords_addrpm" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_port: $ords_port" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_admin: $ords_admin" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_load_from: $ords_load_from" I "NONE" ; fi
 
    # get server specific settings
    ora_lsnr_port=$( cfgGetD "$CONF_FILE" srvr_ora_lsnr_port "$DEF_CONF_FILE" lsnr_port )
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_lsnr_port: $ora_lsnr_port" I "NONE" ; fi

    # decide on what SID or PDB to use for install
    ora_db_sid=$( cfgGet "$CONF_FILE" ora_db_sid )
    ora_db_pdb=$( cfgGet "$CONF_FILE" ora_db_pdb )
    # check config file / command line for PDB only install option
    if [ -z "${srvr_ords_pdbonly:-}" ]; then srvr_ords_pdbonly=$( cfgGet "$CONF_FILE" srvr_ords_pdbonly ); fi
    if [ "${srvr_ords_pdbonly}" == "__UNDEFINED__" ]; then srvr_ords_pdbonly=FALSE; fi

    # set service name based on if we are installing in CDB root or PDB or normal SID
    if [ "${srvr_ords_pdbonly^^}" == "TRUE" ] && [ "${ora_db_pdb}" != "__UNDEFINED__" ] && [ -n "${ora_db_pdb:-}" ]; then 
         db_service="${ora_db_pdb}"
    else db_service="${ora_db_sid}"; fi

    if [ "${db_service}" == "__UNDEFINED__" ] || [ -z "${db_service:-}" ] ; then
        logMesg 1 "could not detect database name from config files." E "NONE" 
        exit 1
    fi 
    logMesg "Installing ORDS in DB: $db_service" I "NONE"

    # check os version
    os_name=$( /bin/grep -E '^NAME=' /etc/os-release | /bin/cut -d= -f2 | /bin/tr -d '"' )
    os_version=$( /bin/grep -E '^VERSION=' /etc/os-release | /bin/cut -d= -f2 | /bin/tr -d '"' )
    os_release=$( echo "${os_version}" | /bin/cut -d. -f1 )
    ords_repo="http://yum.oracle.com/repo/OracleLinux/OL${os_release}/oracle/software/x86_64"

    # static defaults
    ORDS_CONFIG=${ords_admin}/config
    ords_logs=${ords_admin}/logs
    db_host=$( hostname -f )

    # test information
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_path: $ords_path" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_admin: $ords_admin" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_logs: $ords_logs" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ORDS_CONFIG: $ORDS_CONFIG" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_src: $ords_src" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_port: $ords_port" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "db_host: $db_host" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ora_lsnr_port: $ora_lsnr_port" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "db_service: $db_service" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "os_name: $os_name" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "os_version: $os_version" I "NONE" ; fi
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "ords_repo: $ords_repo" I "NONE" ; fi
 
    # Lookup password for database
    secret_name="db_all_${ora_db_sid}"
    db_password=$( getSecret "${secret_name}" )
    if [ "$db_password" == "__UNDEFINED__" ]; then
        logMesg 1 "Password not found for DB, secret: $secret_name" E "NONE" 
        exit 1
    fi


    # install java if it is not arlready installed
    #   Note lsof used by systemctl start script for ords
    if [ "$TEST" == "TRUE" ]; then logMesg 0 "Installing requiredl RPMs: ${ords_java} ${ords_addrpm}" I "NONE" 
        elif [ -f /usr/bin/dnf ]; then /usr/bin/dnf -y install "${ords_java} ${ords_addrpm}"
        else /bin/yum -y install "${ords_java} ${ords_addrpm}"; fi
    if (( $? > 0 )) ; then echo "ERROR could not install required RPMs: ${ords_java} ${ords_addrpm}"; exit 1; fi

    # Set the Java environment, make sure select java is first in path
    JAVA_HOME=$( /usr/sbin/alternatives --list | /usr/bin/grep jre_11_openjdk | /usr/bin/cut -f3 )
    export JAVA_HOME
    export PATH=${JAVA_HOME}/bin:$PATH

    # Load the ords binaries
    case "${ords_load_from}" in
      "repo") load_ords_repo;;
      "file") load_ords_file;;
      "url") load_ords_url;;
      *) logMesg 1 "Invalid install method: ${ords_load_from}" E "NONE"
         exit 1;
         ;;
    esac

        # Install ORDS into the database
        logMesg "ORDS CONFIG: ${ORDS_CONFIG}" I "NONE"
        export ORDS_CONFIG
        ords_features="--feature-sdw true --log-folder ${ords_logs}"
        ords_db="--admin-user SYS --password-stdin --db-hostname ${db_host} --db-port ${ora_lsnr_port} --db-servicename ${db_service}"
        ords_storage="--schema-tablespace SYSAUX --schema-temp-tablespace TEMP"
        logMesg "ORDS COMMAND LINE: ${ords_path}/bin/ords install ${ords_features} ${ords_db} ${ords_storage}" I "NONE"
        /usr/bin/su oracle -c "echo ${db_password} | ${ords_path}/bin/ords install ${ords_features} ${ords_db} ${ords_storage}"
 
        # Configure ORDS standalone server
        logMesg "Configuring ORDS server on port $ords_port" I "NONE"
        if [ "$HTTPS" == "TRUE" ]; then 
            logMesg 0 "Configuring HTTPS https://$( hostname -f):${ords_port}" I "NONE" 
            /usr/bin/su oracle -c "${ords_path}/bin/ords config set standalone.https.host $( hostname -f )"
            /usr/bin/su oracle -c "${ords_path}/bin/ords config set standalone.https.port ${ords_port}"
        else
            logMesg 0 "Configuring HTTP http://$( hostname -f):${ords_port}" I "NONE" 
            /usr/bin/su oracle -c "${ords_path}/bin/ords config set standalone.http.port ${ords_port}"
        fi
        /usr/bin/su oracle -c "${ords_path}/bin/ords config set --global db.serviceNameSuffix \"\" "
        /usr/bin/su oracle -c "${ords_path}/bin/ords config set standalone.access.log /var/log/ords"

        # Configure ORDS auto start
        # Create configuration file
        #   Note ORDS_BASE is the directory under "ords" used by systemctl start
        echo "# ORDS Service Script Configuration File (ords.config)" > /etc/ords.conf
        echo "# Generated by oraORDS.sh $( date )"                    >> /etc/ords.conf
        echo "ORDS_BASE=$( dirname "${ords_path}" )"                  >> /etc/ords.conf
        echo "ORDS_CONFIG=${ORDS_CONFIG}"                             >> /etc/ords.conf
        echo "SERVE_EXTRA_ARGS=--port ${ords_port} --secure"          >> /etc/ords.conf
        echo "JAVA_HOME=${JAVA_HOME}"                                 >> /etc/ords.conf
        /usr/bin/chown oracle:oinstall /etc/ords.conf
        /usr/bin/chmod 750 /etc/ords.conf
        logMesg "Configureing ORDS autostart with config file at: /etc/ords.conf" I "NONE"
 
        # copy man pages
        /usr/bin/cp "${ords_path}"/linux-support/man/ords.1 /usr/share/man/man1/ords.1.gz
        /usr/bin/chmod 644 /usr/share/man/man1/ords.1.gz
        /usr/bin/chown root:root /usr/share/man/man1/ords.1.gz
        /usr/bin/cp "${ords_path}"/linux-support/man/ords.conf.5 /usr/share/man/man5/ords.conf.5.gz
        /usr/bin/chmod 644 /usr/share/man/man5/ords.conf.5.gz
        /usr/bin/chown root:root /usr/share/man/man5/ords.conf.5.gz
        /usr/bin/cp "${ords_path}"/linux-support/man/ords.service.8 /usr/share/man/man8/ords.service.8.gz
        /usr/bin/chmod 644 /usr/share/man/man8/ords.service.8.gz
        /usr/bin/chown root:root /usr/share/man/man8/ords.service.8.gz
 
        # create autostart
        /usr/bin/cp "${ords_path}"/linux-support/ords.sh /etc/init.d/ords
        /usr/bin/chown root:root /etc/init.d/ords
        /usr/bin/chmod 755 /etc/init.d/ords
        /usr/bin/cp "${ords_path}"/linux-support/ords.service /etc/systemd/system/ords.service
        /usr/bin/chown root:root /etc/systemd/system/ords.service
        /usr/bin/chmod 644 /etc/systemd/system/ords.service
        /usr/bin/ln -s "${ords_path}"/bin/ords /usr/local/bin/ords
 
        # fix autostart bugs
        sed -i 's/_ords_base > 0/_ords_base -gt 0/g' /etc/init.d/ords
 
        # enable autostart
        case "$( ps --no-headers -o comm 1 )" in
            'systemd') 
                systemctl enable ords
                systemctl start ords
                ;;
            'init') 
                chkconfig --add ords
                service ords start
                ;;
            *) 
                echo "ERROR autostart not supported on this platform"
                echo "   You will need to manually start ORDS       "
                ;;
        esac
 
        # configure firewall
        logMesg "Configuring firewall for port $ords_port" I "NONE"
        /bin/firewall-cmd --permanent --zone=public --add-port="${ords_port}/tcp"
        /bin/firewall-cmd --reload

        # Setup oracle user environment for ORDS
        echo "export ORDS_CONFIG=${ORDS_CONFIG}"  >> /home/oracle/.bashrc
        echo "export JAVA_HOME=${JAVA_HOME}"      >> /home/oracle/.bashrc 
        echo 'export PATH=${JAVA_HOME}/bin:$PATH' >> /home/oracle/.bashrc

else
    echo "ERROR - invalid command line parameters" >&2
    exit 1
fi

# Uninstall options
# ords --config /path/to/test/config uninstall --admin-user SYS --db-hostname localhost --db-port 1521 --db-servicename orcl --log-folder /path/to/logs

# END
