# Scripts directory

Contains mutltipe scripts used in the lab to build out Oracle databases

-------------------------------------------------------------

## get-ora-lab.sh

simple script to load ora-lab scripts onto VM during creation.
Creates /opt/ora-lab directory and loads scripts from GIT.


This can be called from build tool like Terraform using following commands:

```
"/usr/bin/curl https://raw.githubusercontent.com/ggordham/ora-lab/main/scripts/get-ora-lab.sh > /tmp/get-ora-lab.sh",
"/bin/bash /tmp/get-ora-lab.sh"
```

*Note you need to also copy the server.conf and secure.conf files to the vm prior to running the ora-lab scripts.*

-------------------------------------------------------------

## oraLnxPre.sh

Builds out Linux OS items needed for ora-lab scripts to work

-------------------------------------------------------------

## oraSwStg.sh - script to stage Oracle software (databse and GI).

Script that stages oracle software
- places install media (unzip or runinstaller)
- downloads required patches from MOS
- stages the patches
- downloads and stages OPatch if possible

Sample testing command line

```
oraSwStg.sh --oraver 19 --orasubver 19_9 --stgdir /u01/app/stage --srcdir /mnt/software/Oracle/database/19c --orabase /u01/app/oracle --orahome /u01/app/oracle/product/19/dbhome_1 --test`
```

-------------------------------------------------------------

## oraSwInst.sh - script to install Oracle software (databse and GI).

Sample testing command line

```
oraSwInst.sh --oraver 19 --orasubver 19_9 --srcdir /mnt/software/Oracle/database/19c --stgdir /u01/app/stage --orabase /u01/app/oracle --orahome /u01/app/oracle/product/19/dbhome_1 --test`
```


TODO
- Add log files to scripts (using logMsg)
- Add error checking to critical steps in scripts
- Add to oraSwStg.sh return code for software satge vs patch stage status
- move secrets to safe / vault (want to make generic calls if possible)


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

-------------------------------------------------------------

END
