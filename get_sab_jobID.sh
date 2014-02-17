#!/bin/bash
#
# Script to find SABnzbd job id for given release.  
# Pass this script a single arg which releates to arg2 in SABnzbd post-processing parameters "2 - The original name of the NZB file".
# eg. "./get_sab_jobID.sh Stand.Up.Guys.2012.MULTi.1080p.BluRay.x264-ZEST.nzb"

#define sabnzb parameters needed by this script
#api key
APIKEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#sabnzbd host
SABHOST=localhost
#sabnzbd port
SABPORT=8000

if [ $1 == "" ]; then
    echo "Usage: $(basename ${0}) argv0"
    exit 1
fi

TMPFILE=`tempfile`
echo "Created temp file $TMPFILE"
trap 'rm -f $TMPFILE' exit

RELEASE="$1"

read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

SAB_JOB_ID=unknown

# obtain sabnzbd job id
echo "Calling SAB API to obtain job id for release $RELEASE..."
echo "Reading last 10 entries from SABnzbd history..."
wget -q "http://$SABHOST:$SABPORT/sabnzbd/api?mode=history&start=START&limit=10&output=xml&apikey=$APIKEY" -O $TMPFILE
while read_dom; do
  if [[ $ENTITY = "nzb_name" ]]; then
    echo "$CONTENT"
    if [[ $CONTENT = $RELEASE ]]; then
      echo "Found nzb name match for $RELEASE in history, looking up job id"
      while read_dom; do
        if [[ $ENTITY = "nzo_id" ]]; then
          SAB_JOB_ID=$CONTENT
          #exit
        fi
      done
    else
      echo "No match found"
    fi
  fi
done < $TMPFILE

