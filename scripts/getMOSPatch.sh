#!/bin/bash

# Maris Elsins / Pythian / 2013
# Source: https://github.com/MarisElsins/TOOLS/blob/master/Shell/getMOSPatch.sh
# Inspired by John Piwowar's work: http://only4left.jpiwowar.com/2009/02/retrieving-oracle-patches-with-wget/
# Usage:
# getMOSPatch.sh reset=yes  
#     Use to refresh the platform and language settings
#
# getMOSPatch.sh patch=patchnum_1[,patchnum_n]* [download=all] [regexp=...]
#     Use to download one or more patches. If "download=all" is set all patches will be downloaded 
#     without user interaction, you can also define regular expressen by passing regexp to filter the patch filenames.  
#
# getMOSPatch.sh patch=patchnum_1[,patchnum_n]* [download=all] [regexp=...]
#
# v1.0 Initial version 
# v1.1 Added support for multipart patches, previously these were simply ignored.
# v1.2 This version of getMOSPatch is now obsolete. Use https://github.com/MarisElsins/getMOSPatch/raw/master/getMOSPatch.jar instead
# v1.3 GG - 20220524 - fixed regex search to only look at patch filename, and not all fields in download URL. Removed perl requirement.

# exit on the first error
set -e

echo 
echo "From Maris Elsins original author"
echo "This version of getMOSPatch is obsolete (from 2013)" 
echo "Download getMOSPatch V2 from: https://github.com/MarisElsins/getMOSPatch/raw/master/getMOSPatch.jar"
echo "Check the README for the new version here: https://github.com/MarisElsins/getMOSPatch/blob/master/README.md"
echo "Read my blog post about it here: http://bit.ly/getMOSPatchV2"
echo
echo "GG - updated in 2022 to fix a few bugs of this script and clean up the code some"

# standard variables that could be passed - prevent undefined errors
export p_patch p_download p_destination p_reset p_xml p_regexp p_readme p_debug

# Setting some variables for the files I'll operati with
PREF=$( basename "$0" )
CD=$( dirname "$0" )
CFG=${CD}/.${PREF}.cfg         # Configuration of language and platform for MOS patch
TMP1=${CD}/.${PREF}.tmp1       # main download of full HTML from MOS
TMP2=${CD}/.${PREF}.tmp2       # List of URL's to download for patch
TMP3=${CD}/.${PREF}.tmp3
TMP4=${CD}/.${PREF}.tmp4       # Temporary details on each sub patch file
COOK=${CD}/.${PREF}.cookies    # cookies to hold current login state for session of MOS

# Processing the arguments by setting the respective variables
# all arguments are passed to the shell scripts in form argname=argvalue
# This command sets the following variables for each argument: p_argname=argvalue
for var in "$@" ; do eval "export p_${var}"; done

# Did we get all the variables we need?
if [ -z "$p_patch" ] && [ "$p_reset" != "yes" ] ; then
  echo "Not enough parameters.
  Usage:
  $PREF reset=yes  
             Use to refresh the platform and language settings
  $PREF patch=patchnum_1[,patchnum_n]* [download=all] [readme=yes] [xml=yes]
            [destination=</path>] [debug=yes]
      Download one or more patches from MOS. Options:
         patch=patchnum_1,patchnum_n    List of patche numbers to download
         regexp=filter      Regular Expression filter to apply to patch file name
         xml=yes            Download patch XML file also
         readme=yes         Download patch readme file also
         destination=/path  Directory path to download patches to
         download=all       All patches will be downloaded without user interaction
         debug=yes          Temporary files will not be deleted so you 
                               can view HTML download steps
     Note: you can provide your MOS username and password with envrionment
           variables, or you will be prompted.
           mosUser=username
           mosPass=password"
  exit 1
fi

# Clean up temporary files
function clean_temp {
    # if debug mode, then don't clean up temporary files
    if [ "$p_debug" ] && [ "$p_debug" == "yes" ]; then
        echo "DEBUG mode, you can view temp files at:
              $TMP1
              $TMP2
              $TMP3
              $TMP4"
    else
        [[ -f "$TMP1" ]] && rm -f "$TMP1"
        [[ -f "$TMP2" ]] && rm -f "$TMP2"
        [[ -f "$TMP3" ]] && rm -f "$TMP3"
        [[ -f "$TMP4" ]] && rm -f "$TMP4"
        echo > /dev/null
    fi
}

# Clean wgetrc file of username / password
function clean_wgetrc {

  touch ~/.wgetrc
  sed -i '/^user=/d' ~/.wgetrc
  sed -i '/^password=/d' ~/.wgetrc
  chmod 600 ~/.wgetrc

}


# change into p_destination if defined, so we can run this from crontab or from other script
if [ "$p_destination" ]; then
    echo "changing directory to $p_destination"
    [ -d "$p_destination" ] || mkdir -p "$p_destination"
    pushd "$p_destination" >/dev/null 2>&1
    UNPUSHD="$?"
fi

# Reading the MOS user credentials. Set environment variables mosUser and mosPass if you want to skip this.
[[ $mosUser ]] || read -rp "Oracle Support Userid: " mosUser;
[[ $mosPass ]] || read -srp "Oracle Support Password: " mosPass;
echo

# clean up the wgetrc and test that we can login
# this also generates a cookie that we can use for later commands
clean_wgetrc
echo "user=$mosUser" >> ~/.wgetrc
echo "password=$mosPass" >> ~/.wgetrc
set +e
wget --save-cookies="$COOK" --keep-session-cookies --no-check-certificate "https://updates.oracle.com/Orion/SimpleSearch/switch_to_saved_searches" -O "$TMP1" -o "$TMP2" --no-verbose
RESULT=$?
clean_wgetrc

# if we can't login to MOS exit
if [ ${RESULT} -ne 0 ] ; then
  echo "ERROR! - login to MOS failed!"
  cat "$TMP2"
  [[ -f "$COOK" ]] && rm -f "$COOK"   # Clean up the cookies file
  exit 2
fi

set -e
clean_temp 

# If we run the script the first time we need to collect Language and Platform settings.
# This part also executes if reset=yes
# This part fetches the simple search form from mos and parses all Platform and Language codes
if [ ! -f "$CFG" ] || [ "$p_reset" == "yes" ] ; then
    echo; echo "Getting the Platform/Language list"
    wget --no-check-certificate --load-cookies="$COOK" "https://updates.oracle.com/Orion/SavedSearches/switch_to_simple" -O "$TMP1" -q

    # Prompt the user to select a language / platform code
    echo "Available Platforms and Languages:"
    grep -A999 "<select name=plat_lang" "$TMP1" | grep "^<option"| grep -v "\-\-\-" | awk -F "[\">]" '{print $2" - "$4}' > "$TMP2"
    read -rp "Comma-delimited list of required platform and language codes: " PlatLangCodes;
    echo "$PlatLangCodes" > "$CFG"
    for PLATLANG in $( echo "$PlatLangCodes" | sed "s/,/ /g" | xargs -n 1 echo )
    do
        grep "^$PLATLANG " "$TMP2" | sed "s/ - /;/g" >> "$CFG"
    done
    echo "Configuration saved"
    
    clean_temp

fi

# if now regular expression was passed on paramter, then set to all
if [ -z "$p_regexp" ] ; then
  p_regexp=".*"
fi

# Iterate patches one by one
for pp_patch in $(echo "${p_patch}" | sed "s/,/ /g" | xargs -n 1 echo)
do
    IFS=$'\n'
    # Iterate languages one by one
    while read -r PL; do
        PLATLANG=$( echo "$PL" | awk -F";" '{print $1}' )
        PLDESC=$( echo "$PL" | awk -F";" '{print $2}' )
        protpatches=0
        echo
        echo "Getting list of files for patch $pp_patch for \"${PLDESC}\""
       
        # Download the list of patches available from search into TMP1, then grep out the lines for Download and clean out to get the URLs for each download, put that in TMP2
        wget --no-check-certificate --load-cookies="$COOK" "https://updates.oracle.com/Orion/SimpleSearch/process_form?search_type=patch&patch_number=${pp_patch}&plat_lang=${PLATLANG}" -O "$TMP1" -q
       
        # Check if any of the patches are password protected (this seems too global)
        if [ "$( grep "javascript:showDetails(\"/Orion/PatchDetails/process_form" "$TMP1" | grep -ce "title=\"Download Password Protected Patch" )" -gt 0 ]
        then
          echo "!!! This patch contains password protected files (not listed). Use My Oracle Support to download them!"
          protpatches=1
        fi
       
        # create short list of download URL's in TMP2 file, fixed grep to look at only filename field (field 4)
        #OLD# grep "Download/process_form" "$TMP1" | grep -E "${p_regexp}" | sed 's/ //g' | sed "s/.*href=\"//g" | sed "s/\".*//g" > "$TMP2"
        grep "Download/process_form" "$TMP1" | sed 's/ //g' | sed "s/.*href=\"//g" | sed "s/\".*//g" | awk -F = -v filter="${p_regexp}" '$4 ~ filter { print $0 }' > "$TMP2"
       
        # loop through each entry in the list excluding password protected lines or translation required 
        #  get the list of sub patches download files 
        grep "javascript:showDetails(\"/Orion/PatchDetails/process_form" "$TMP1" | grep -v -e "title=\"Download Password Protected Patch" -e "Download/process_form" -e  "class=\"OraTableCellNumber" -e "title=\"Translation Required" | sed 's/ //g' | sed "s/.*href='javascript:showDetails(\"//g" | sed "s/\".*//g" | while read -r LINE
          do
            wget --no-check-certificate --load-cookies="$COOK" "https://updates.oracle.com/${LINE}" -O "$TMP4" -q
            # look for download file, updated regex search to only look at file name field 
            #OLD# grep "Download/process_form" "$TMP4" | grep -E "${p_regexp}" | sed 's/ //g' | sed "s/.*href=\"//g" | sed "s/\".*//g" >> "$TMP2"
            grep "Download/process_form" "$TMP1" | sed 's/ //g' | sed "s/.*href=\"//g" | sed "s/\".*//g" | awk -F = -v filter="${p_regexp}" '$4 ~ filter { print $0 }' > "$TMP2"
       
        done
       
        # if we have a list of patch files then see if we are set to download all
        if [ "$( wc -l "$TMP2" | cut -d ' ' -f 1 )" -gt 0 ] ; then
            if [ "$( wc -l "$TMP2" | cut -d ' ' -f 1 )" -eq 1 ] && [ $protpatches -eq 0 ] ; then
                DownList="1"
            else
                set +
                if [ "$p_download" == "all" ] ; then
                    DownList=""
                else
                    awk -F"=" '{print NR " - " $NF}' "$TMP2" | sed "s/[?&]//g"
                    read -rp "Comma-delimited list of files to download: " DownList
                    DownList=$( echo -n "${DownList}" | sed  "s/,/p;/g" )
                fi
                set -
            fi
            touch "$TMP3"
            sed -n "${DownList}p" "$TMP2" >> "$TMP3"
            echo "Files to download:"
            sed -n "${DownList}p" "$TMP2" | awk -F"=" '{print $NF}' | sed "s/[?&]//g" | sed "s/^/  /g"
        else
            echo "ERROR! no patch available"
        fi
    done < "$CFG"  # end of language iteration loop
done               # end of patch number loop

# if we have a list of patches in TMP3 file then start the download process
if ([ ! -z "${p_patch}" ] && [ "$( wc -l "$TMP3" | cut -d ' ' -f 1 )" -gt 0 ]) ; then
    echo
    echo "Downloading the patches:"
    # Loop through the TMP3 file and download patches
    while read -r URL; do

        # get the patch filename from the download URL and see if it already exists and is healthy
        fname=$( echo "$URL" | awk -F"=" '{print $NF;}' | sed "s/[?&]//g" )
        if [ -f "$fname" ]; then
            unzip -t -qq "$fname" || rm "$fname"
        fi
       
        # if the file already exists, check if a newer version is available for download
        # curl -R set timestamp of the file to source
        # curl -z <file> check if file is newer than what is available on the server
        if [ -f "$fname" ]; then
            echo "Note: File $fname exist" ;
            echo "Checking if file $fname has changed on server ..." ;
            curl -R -b "$COOK" -c "$COOK" --insecure -z "$fname" --output "$fname" -L "$URL"
            echo "$fname completed with status: $?"
        else
            echo "Downloading file $fname ..."
            curl -R -b "$COOK" -c "$COOK" --insecure --output "$fname" -L "$URL"
            echo "$fname completed with status: $?"
        fi
        
        fname_=${fname%.zip}
        ## download readme and rename to html or txt
        if [ "$p_readme" ] && [ "$p_readme" == "yes" ]; then
            echo
            echo "Downloading readme file ..."
            curl -R -b "$COOK" -c "$COOK" --insecure --output "$fname_.readme" -L "https://updates.oracle.com/Orion/Services/download?type=readme&bugfix_name=$pp_patch"
            if [ -f "$fname_.readme" ]; then
                if [ "$( file -b "$fname_.readme" )" == "HTML document text" ]; then
                    mv "$fname_.readme" "$fname_.html"
                else
                    mv "$fname_.readme" "$fname_.txt"
                fi
            fi
        fi
        
        ## download xml
        if [ "$p_xml" ] && [ "$p_xml" == "yes" ]; then
            echo
            echo "Downloading xml file ..."
            curl -R -b "$COOK" -c "$COOK" --insecure --output "$fname_.xml" -L "https://updates.oracle.com/Orion/Services/search?bug=$pp_patch"
        fi
        
    done < "$TMP3"
fi

# clean up temporary files and cookies
clean_temp
[[ -f "$COOK" ]] && rm -f "$COOK"   # Clean up the cookies file

#leave the pushd if defined, running popd
if [ $UNPUSHD ]; then
    popd >/dev/null 2>&1
fi

exit 0
# END
