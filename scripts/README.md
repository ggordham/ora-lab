# Scripts directory

Contains mutltipe scripts used in the lab to build out Oracle databases.
Generally scripts can be run independently.  Most options will come from .conf files or can be over-ridden on the command line.

---------------------------------------------
# Current Status
Basic testing has been performed on the folloiwng modules / OS versions / database versions.

|                | 9iR2 | 10gR1 | 10gR2 | 11gR1 | 11gR2 | 12cR1      | 12cR2      | 18c        | 19c        | 21c   | 23c (beta) |
| -------------- | ---- | ----- | ----- | ----- | ----- | ---------- | ---------- | ---------- | ---------- | ------- | ---------- |
| oraLnxPre.sh   |      |       |       |       |       |            |            |            | W (7,8)    | W (8)   | W (8)      |
| oraSwStg.sh    |      |       |       |       |       |            |            |            | W (G,D)    | W (G,D) | W (8)      |
| oraSwInst.sh   |      |       |       |       |       |            |            |            | W (7,8)    | W (8)   | W (8)      |
| oraDBCA.sh     |      |       |       |       |       |            |            |            | W          | W       | W          |
| oraLsnr.sh     |      |       |       |       |       |            |            |            | W          | W       | W          |
| oraTNS.sh      |      |       |       |       |       |            |            |            | W          | W       | W          |
| oraORDS.sh     |      |       |       |       |       |            |            |            | W          | W       | E          |
| oraDBSamp.sh   |      |       |       |       |       |            |            |            | W          | W       | W          |
| oraRWLInst.sh  |      |       |       |       | T     |            |            |            | W          | W       | W          |
| oraRWLSetup.sh |      |       |       |       | T     |            |            |            | W          | W       | W          |
| oraUserCFG.sh  |      |       |       |       |       |            |            |            | W (7,8)    | W (8)   | W (8)      |
|                |      |       |       |       |       |            |            |            |            |         |            |
| getMOSPatch.sh |      |       |       |       |       |            |            |            | W          | W       |            |
| oraRWLRun.sh   |      |       |       |       | T     |            |            |            | W          | W       | W          |
| NCDB / PDB     | NCDB | NCDB  | NCDB  | NCDB  | NCDB  | NCDB / PDB | NCDB / PDB | NCDB / PDB | NCDB / PDB | PDB     | PDB        |
|                |      |       |       |       |       |            |            |            |            |         |            |
| Linux Versions |      |       |       |       |       |            |            |            |            |         |            |
| OEL 4          | Y    | Y     | N     | N     | N     | N          | N          | N          | N          | N       | N          |
| OEL 5          | N    | N     | Y     | Y     | Y     | N          | N          | N          | N          | N       | N          |
| OEL 6          | N    | N     | N     | N     | Y     | Y          | Y          | Y          | N          | N       | N          |
| OEL 7          | N    | N     | N     | N     | Y     | Y          | Y          | Y          | Y          | Y       | N          |
| OEL 8          | N    | N     | N     | N     | N     | N          | N          | N          | Y          | Y       | Y          |
| OEL 9          | N    | N     | N     | N     | N     | N          | N          | N          | N          | N       |            |

Notes:
- W = working (OS versions, GRID, DB)
- T = testing
- NCDB / PDB status still in progress, PDB tested first on working lines
- Y - compatible
- N - not compatible

-------------------------------------------------------------

## tstOraInst.sh

Start of a script that will orchestrate the full build out of an Oracle database server by walking through the steps set in a server.conf file.
This is currently a skelleton script and will be worked into a more formal script in the future.

TODO
 - make this a more robust full kick off script
 - add feature to install multiple oracle homes and grid home

-------------------------------------------------------------

## get-ora-lab.sh

simple script to load ora-lab scripts onto VM during creation.
Creates /opt/ora-lab directory and loads scripts from GIT.

```
Usage: get-ora-lab.sh [-h --debug --test ]
-h          give this help screen
--refresh   download scripts only
--debug     turn on debug mode
--test      turn on test mode
--version | -v Show the script version
```

This can be called from build tool like Terraform using following commands:

```
"/usr/bin/curl https://raw.githubusercontent.com/ggordham/ora-lab/main/scripts/get-ora-lab.sh > /tmp/get-ora-lab.sh",
"/bin/bash /tmp/get-ora-lab.sh"
```

*Note you need to also copy the server.conf and secure.conf files to the vm prior to running the ora-lab scripts.*

-------------------------------------------------------------

## oraLnxPre.sh

Builds out Linux OS items needed for ora-lab scripts to work

```
oraLnxPre.sh
   used to prepare Linux server for ora-lab
   version: 1.0

Usage: oraLnxPre.sh [-h --debug --test ]
-h          give this help screen
--disks [list of disks to format+mount]
--dfs   [disk fs type]
--sftno  Disables mounting NFS of software media
--sftt  [Software mount type]
--sftm  [Software mount point]
--sfts  [Software source]
--lsnp  [Oracle Listener Port]
--pkgs  [Linux packages to install]
--pkgt  [Linux package tool]
--grid  Additional OS changes to support GRID
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version
```

-------------------------------------------------------------

## oraSwStg.sh - script to stage Oracle software (databse and GI).

Script that stages oracle software based on settings in the servers.conf
- places install media (unzip or runinstaller)
- downloads required patches from MOS
- stages the patches
- downloads and stages OPatch if possible

```
oraSwStg.sh
   used to stage Oracle DB software + patches
   version: 1.0

Usage: oraSwStg.sh [-h --debug --test ]
-h          give this help screen
--oratype [grid | db]
--oraver [Oracle version]
--orasubver [Oracle minor version]
--orabase [Oracle base]
--orahome [Oracle home]
--srcdir [Source directory]
--stgdir [Staging Directory]
--guser Create grid user and ASM groups
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version
```

Sample testing command line

```
oraSwStg.sh --oraver 19 --orasubver 19_9 --stgdir /u01/app/stage --srcdir /mnt/software/Oracle/database/19c --orabase /u01/app/oracle --orahome /u01/app/oracle/product/19/dbhome_1 --test`
```

TODO
 - Test GRID software staging

-------------------------------------------------------------

## oraSwInst.sh - script to install Oracle software (databse and GI).

Runs through the software install process using runInstaller.

```
oraSwInst.sh
   used to install Oracle DB software
   version: 1.0

Usage: oraSwInst.sh [-h --debug --test ]
-h          give this help screen
--oratype [grid | db] 
--oraver [Oracle version]
--orasubver [Oracle minor version]
--orabase [Oracle base]
--orahome [Oracle home]
--stgdir  [Staging directory]
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version
```

Sample testing command line

```
oraSwInst.sh --oraver 19 --orasubver 19_9 --srcdir /mnt/software/Oracle/database/19c --stgdir /u01/app/stage --orabase /u01/app/oracle --orahome /u01/app/oracle/product/19/dbhome_1 --test`
```

TODO
- Add error checking to critical steps in scripts
- Add to oraSwStg.sh return code for software satge vs patch stage status
- Add support for legacy non-unzip home process
- Add support for GRID software install for stand alone


-------------------------------------------------------------

## oraDBCA.sh - script to create an Oracle database using Database Creation Assistant

Runs the Database Creation Assistant (DBCA) to create a database based on settings in the server.conf or defaults.conf.

```
oraDBCA.sh
   used to run DBCA to create Oracle database
   version: 1.0

Usage: oraDBCA.sh [-h --debug --test ]
-h          give this help screen
--orahome [Oracle home]
--datadir [DB data directory]
--dbsid   [DB SID]
--dbtype  [DB type CDB|NCDB]
--dbpdb   [DB pdb name for CDB only]
--insecure do not remove passwords from response file
--dbcatemp [DBCA Template response file]
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version
```

-------------------------------------------------------------

## oraLsnr.sh - script to create an Oracle Listener

Runs the Network Creation Assistant (NETCA) to create a local listener based on settings in the server.conf or defaults.conf.

```
oraLsnr.sh
   used to run NETCA to create Oracle db listener
   version: 1.0

Usage: oraLsnr.sh [-h --debug --test ]
-h          give this help screen
--orahome [Oracle home]
--port    [TCP Port]
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version
```

-------------------------------------------------------------

## oraORDS.sh - script to install Oracle Rest Data Services

Installs the Oracle Rest Data Services (ORDS) software and configures the default ORDS server setting it for auto start on server restart.  Takes settings from server.conf and defaults.conf

```
oraORDS.sh
   Install and setup Oracle Rest Data Services
   version: 1.0

Usage: oraORDS.sh [-h --debug --test ]
-h          give this help screen
--ordspath  [ORDS install path]
--ordsadmin [ORDS admin path]
--ordssrc   [ORDS Source zip file]
--ordsport  [ORDS port]
--pdbonly   install ORDS in PDB only not CDB
--httpsno   disable HTTPS configuration
--debug     turn on debug mode
--test      turn on test mode
--version | -v Show the script version
```

TODO
 - Fix DB install part that is not working, have to uninstall and reinstall ORDS.

-------------------------------------------------------------

## oraUsrCfg.sh - script to configure the oracle OS user post build

This script puts a few things in place like extra SSH keys and default profile scirpts for the oracle user at the end of a build.

```
oraUsrCfg.sh
   used to run DBCA to create Oracle database
   version: 1.0

Usage: oraUsrCfg.sh [-h --debug --test ]
-h          give this help screen
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version
```

-------------------------------------------------------------

## oraDBSamp.sh - installs the sample schemas into the database

Installs the sample schemas into the database.  Can use a local backup copy of the sample schema scripts or pull fresh copy from GITHUB.

```
oraDBSamp.sh
   Install and setup Oracle Rest Data Services
   version: 1.0

Usage: oraDBSamp.sh [-h --debug --test ]
-h          give this help screen
--datatbs [Data Tablespace]
--temptbs [Temp Tablespace]
--stgdir  [Staging Directory]
--debug     turn on debug mode
--test      turn on test mode
--version | -v Show the script version
```

-------------------------------------------------------------

## RWL load simulotor related scripts

There are three scripts for the RWL Load simulator.
1. Install the software - oraRWLInst.sh
2. Setup DB and schemas - oraRWLSetup.sh
3. Run a simulation - oraRWLRun.sh

These scripts pull settings from the server.conf and possilby defaults.conf based on the setting.
You would normally only run the first two (Inst / Setup) from automation.

```
oraRWLInst.sh
   used to run RWP*Load Simulator OLTP .
   version: 1.0

Usage: oraRWLInst.sh [-h --debug --test ]
-h          give this help screen
--url     [Full download URL for software]
--dir     [Install direcotry]
--outdir  [RWL output directory]
--proj    [RWL project name]
--dbsid   [DB SID]
--dbpdb   [DB pdb name for CDB only]
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version

 Note: outdir is also location of RWL project
```

```
oraRWLSetup.sh
   used to run RWP*Load Simulator OLTP .
   version: 1.0

Usage: oraRWLSetup.sh [-h --debug --test ]
-h          give this help screen
--dir     [Install direcotry]
--outdir  [RWL output directory]
--proj    [RWL project name]
--dbsid   [DB SID]
--dbpdb   [DB pdb name for CDB only]
--datadir [DB data directory]
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version

 Note: outdir is also location of RWL project
```

```
oraRWLRun.sh
   used to run RWP*Load Simulator OLTP .
   version: 1.0

Usage: oraRWLRun.sh [-h --debug --test ]
-h          give this help screen
--dbsid   [DB SID to set ENV]
--proj    [RWL Project name]
--sec     [Length of test in seconds]
--proc    [Number of processes to start]
--outdir  [RWL output directory]
--noverify  Skip RWL schema verification step
--debug     turn on debug mode
--test      turn on test mode, disable DBCA run
--version | -v Show the script version

 Note: outdir is also location of RWL project
```

-------------------------------------------------------------
## getMOSPatch.sh - script originall from Maris Elsins

Used to download Oracle patches from MOS directly, used in batch mode in these automation scripts.
For more details see the script itself for basic settings.
A sample session would look something like this:

```
export mosUser=<your MOS username>
export mosPass=<your MOS Password>
echo "226P;Linux x86-64" > ./.getMOSPatch.sh.cfg
getMOSPatch.sh patch=123456 destination=/u01/app/oracle/patchstage
```

Note: this is downloading Linux x86-64 platform, use the script in interactive mode to get a list of platforms with reset=yes parameter."

Note: for patches that have multiple versions like a one off for a RU or OPatch you can use REGEXP option to filter.
This example will download the patch 6880880 where the filename also contians 19

`getMOSPatch.sh patch=6880880 regexp=19 destination=/u01/app/oracle/patchstage`

Note: when doing RU patches be sure to be specific, E.G. to get 19.10 use 1910 not 191 which will put 1911, 1912, etc.

TODO
- replace wget with curl to remove dependency
- add more error checking and messages when login screen is returned vs getting a file.

-------------------------------------------------------------

END
