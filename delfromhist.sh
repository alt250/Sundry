#!/bin/bash
#
# Delete entry from SAB history
# Used from AutoProcessXXX.sh script
# Does the following; 
# a) uses SAB API to remove release from SAB download history
# b) Checks if nzb backup location is set in config and if true, deletes corresponding .nzb file
# Script should be passed one arg which corresponds to arg2 from SABnzbd - "The original name of the NZB file"

# changelog
# 03/01/13 - first draft
# 06/07/13 - added code to delete nzb backup file as otherwise there is history of the download in the nzbbackup directory where nzb files are stored

#define sabnzb parameters needed by this script
#api key
APIKEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#sabnzbd host
SABHOST=localhost
#sabnzbd port
SABPORT=8000

echo "Sleeping for 10 seconds to allow parent script time to exit"
sleep 10
echo "End Sleep"
TMPFILE=`tempfile`
echo "Created temp file $TMPFILE"
trap 'rm -f $TMPFILE' exit

RELEASE="$1"
echo "Release to delete: $RELEASE"

read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

# delete nzb backup file
echo "Calling SAB API to delete NZB backup file..."
wget -q "http://$SABHOST:$SABPORT/sabnzbd/api?mode=get_config&section=misc&output=xml&apikey=$APIKEY" -O $TMPFILE
echo "NZB Backup File to delete: $RELEASE.gz"
while read_dom; do
	if [[ $ENTITY = "nzb_backup_dir" ]]; then
      if [[ ! -z $CONTENT ]]; then # is not null
        echo "nzbbackup directory : $CONTENT"   
        echo "Deleting nzb backup file: $CONTENT/$RELEASE.gz"
        rm -f "$CONTENT/$RELEASE.gz" > /dev/null
      fi
    fi
done < $TMPFILE
echo "... Done"

# delete job from history log
echo "Calling SAB API to delete job from history..."
wget -q "http://$SABHOST:$SABPORT/sabnzbd/api?mode=history&start=START&limit=10&output=xml&apikey=$APIKEY" -O $TMPFILE
while read_dom; do
	if [[ $ENTITY = "nzb_name" ]]; then
        if [[ $CONTENT = $RELEASE ]]; then
		  echo "Found nzb name match for $RELEASE in history, looking up job id"
		  while read_dom; do
		    if [[ $ENTITY = "nzo_id" ]]; then
		      echo "Job Id: $CONTENT"
			  echo "Issuing API call to delete entry from history"
			  wget -qO - "http://$SABHOST:$SABPORT/sabnzbd/api?mode=history&name=delete&value=$CONTENT&del_files=1&apikey=$APIKEY"
              exit
            fi
		  done
		fi
    fi
done < $TMPFILE
echo "... Done"
