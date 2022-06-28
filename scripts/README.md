#Scripts directory

Contains mutltipe scripts used in the lab to build out Oracle databases

============================================================================
##oraSwStg.sh - script to stage Oracle software (databse and GI).

Sample testing command line

`./oraSwInst.sh --oraver 19 --orasubver 19_9 --srcdir /mnt/software/Oracle/database/19c --orabase /u01/app/oracle --orahome /u01/app/oracle/product/19/dbhome_1 --test`

============================================================================
##oraSwInst.sh - script to install Oracle software (databse and GI).

Sample testing command line

`./oraSwStg.sh --oraver 19 --orasubver 19_9 --stgdir /u01/app/stage --srcdir /mnt/software/Oracle/database/19c --orabase /u01/app/oracle --orahome /u01/app/oracle/product/19/dbhome_1 --test`


TODO
- Add log files to scripts (using logMsg)
- Add error checking to critical steps in scripts
- Add to oraSwStg.sh return code for software satge vs patch stage status
- move secrets to safe / vault (want to make generic calls if possible)


============================================================================
##getMOSPatch.sh - script originall from Maris Elsins

Used to download Oracle patches from MOS directly, used in batch mode in these automation scripts.
For more details see the script itself for basic settings.
A sample session would look something like this:

```
export mosUser=<your MOS username>
export mosPass=<your MOS Password>
getMOSPatch.sh patch=123456 destination=/u01/app/oracle/patchstage
```

Note: for patches that have multiple versions like a one off for a RU or OPatch you can use REGEXP option to filter.
This example will download the patch 6880880 where the filename also contians 19

`getMOSPatch.sh patch=6880880 regexp=19 destination=/u01/app/oracle/patchstage`

Note: when doing RU patches be sure to be specific, E.G. to get 19.10 use 1910 not 191 which will put 1911, 1912, etc.


============================================================================
END
