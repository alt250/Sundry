#!/bin/bash
#
# SABnzbd post-processing script to be used with XXX releases.
# Does the following:
# 1. Removes supplementary files eg. .diz, .nfo
# 2. Renames file to that of its download sub-directory name and moves it up one directory to parent dir.
#    It does this as there is a greater likelihood the parent directory name will be relevent to the release when compared to the  
#    extracted file.
# 3. Does basic scene name comvention check for XXX within filename.  If found, a) strips from filename everything from XXX inclusive.
# 4. Moves file to destination directory defined in variable DESTDIR
# 5. Removes old download sub-directory
# 6. Calls child script "delfromhist.sh".  Is passed $2 from this script which is SABs arg2 (The original name of the NZB file)
#    Does the following; 
#    a) uses SAB API to remove release from SAB download history
#    b) Checks if nzb backup location is set in config and if true, deletes corresponding .nzb file


# changelog
# 18/12/12 - first draft
# 23/12/12 - added .url extention
# 26/12/12 - added code to automatically delete entry from sabnzbd history queue
# 03/01/13 - created delfromhist.sh child script. called as last step with nohup to allow this script to terminate but leave child running.
#            as this script needs to exit before as api call to delete itself from queue does not work.  running in a child process that has no
#            dependency on this script is the way to make it work.
#          - changed find to remove release name.  wasnt catching files with extensions that didnt have the same name as the downloaded release
#          - added .html to file delete list
# 19/07/13 - renamed to autoProcessXXX.sh
#          - 1) rename extracted file to that of parent dir
#            2) move renamed file in 1) up one level to parent dir and remove (if empty) old sub-dir
#          - check for scene name convention.  eg. .XXX. and strip everything from XXX to end of filename
#          - move processed file to final location
# 22/07/13 - added .txt to extensions to be deleted
# 18/01/14 - added .jpg to extensions to be deleted
#          - added -f flag to mv command to ensure files moved to destination do not fail due to existing target file
#          - renamed variable "dirname" to ensure it does not interfere with the call out to "dirname" when getting parentdir
#          - added logic to the move section to check the file sizes. if a larger (720p) mp4 file exists at the target location already, then
#          - assume we want to keep the newer smaller non-720p mp4 just downloaded.  Therefore force an overwrite during move.  Otherwise take
#          - no action.  Hopefully this will see fewer .mp4 files lurking in the Unknown directory, needing manual tidying.
# 29/01/14 - changed clean-up files find command. -regexp to -iregexp for caseinsensitive. regex syntax change to extentions 
# 17/02/14 - rewrote logic for deciding what to do if file already exists at destination; script now uses OVERWRITE and RENAME vers as means to decide what action to take
#          - added flag to choose whether to call the clean-up sab history child script.
#          - reworked some of the variables in this script to better describe their use
#          - changed filename maniuplation so as to avoid call outs to dirname and basename

#This not the extract dir (that is set from sab etc), this is the final location where file must be moved to once the file has been auto-extracted
DESTDIR=/mnt/eddie/Stuff2

#Should the script overwrite existing target?  0=NO, 1=YES
OVERWRITE=0

#Set this to have the script decide whether to rename a file (when one exists at destination) by adding timestamp or to silently fail by deleting the newly downloaded file as assumed it's unwanted
RENAME=1

#Should child script be called to clean up history. 0=NO, 1=YES.  Helpful during debugging.
CALLCLEANUP=1

if [ ! -z $7 ] && [ $7 -gt 0 ]; then
    echo "post-processing failed, bypassing script"
    exit 1
fi

# process files
echo 
echo $(date)
echo "Removing supplimentary files for $1"

# extensions removed:
# .nfo
# .diz
# .url
# .htm/.html
# .jpg
# .png
# .txt
# .db

# look for files with extensions as per below iregex, delete them if found
echo -n "Cleaning extra support files... "
find "$1" -regextype posix-extended -iregex '.*\.(nfo|diz|url|htm|html|jpg|png|txt|db)' -exec rm -f {} +
echo -e "Done\n"

# rename extracted file to name of parent directory and move to parent directory
echo "Renaming extracted file to name of parent directory... "
while read file
do

  # Example.
  # $1 = /mnt/eddie/cache/NG/Unknown/WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.XXX.720p.MP4-KTR
  # file = /mnt/eddie/cache/NG/Unknown/WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.XXX.720p.MP4-KTR/wpa.14.02.14.aiden.starr.and.sadie.kennedy.mp4

  SABEXTRACTDIR=${1%/*}              # /mnt/eddie/cache/NG/Unknown
  RLS_DIRNAME=${file%/*}             # /mnt/eddie/cache/NG/Unknown/WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.XXX.720p.MP4-KTR
  RLS_FNAME=${file##*/}              # wpa.14.02.14.aiden.starr.and.sadie.kennedy.mp4
  RLS_EXT=${file##*.}                # mp4
  RLS_NEW_FNAME=${RLS_DIRNAME##*/}   # WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.XXX.720p.MP4-KTR
  
  echo "SABEXTRACTDIR: $SABEXTRACTDIR"
  echo "RLS_DIRNAME  : $RLS_DIRNAME"
  echo "RLS_FNAME    : $RLS_FNAME"
  echo "RLS_EXT      : $RLS_EXT"
  echo "RLS_NEW_FNAME: $RLS_NEW_FNAME" 

  if [ -n "$RLS_EXT" -a  -n "$RLS_DIRNAME" -a -n "$RLS_NEW_FNAME" ]
  then
    echo "mv $file $SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT"
    mv "$file" "$SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT"
  fi
done < <(find "$1" -maxdepth 1 -type f)
echo -e "Done\n"

# if filename is scene standard and contains XXX, then rename to strip everything after XXX inclusive
echo -n "Checking for Scene Naming Convention... "
if [[ "$RLS_NEW_FNAME" == *.XXX.* ]]; then
  echo "Found"
  TMP_OLD_FNAME="$RLS_NEW_FNAME"
  echo "Before : $TMP_OLD_FNAME"           # WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.XXX.720p.MP4-KTR
  RLS_NEW_FNAME="${TMP_OLD_FNAME%.XXX.*}"
  echo "After  : $RLS_NEW_FNAME"           # WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy
  echo "mv $SABEXTRACTDIR/$TMP_OLD_FNAME.$RLS_EXT $SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT"
  mv "$SABEXTRACTDIR/$TMP_OLD_FNAME.$RLS_EXT" "$SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT"   # /mnt/eddie/cache/NG/Unknown/WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.XXX.720p.MP4-KTR.mp4 /mnt/eddie/cache/NG/Unknown/WhippedAss.14.02.14.Aiden.Starr.And.Sadie.Kennedy.mp4
else
  echo "Not found"
fi
echo -e "Done\n"

# move processed file to dest location
if [ -f $DESTDIR/$RLS_NEW_FNAME.$RLS_EXT ]; then  # a file already exists at the target location
  echo "Found file with same name at target location"
  if [ $OVERWRITE = 1 ]; then  # OVERWRITE var set, move file to destination with -f force to overwrite existing file
    echo "OVERWRITE enabled, overwriting existing file"
    echo "Moving processed file to : $DESTDIR... "
    echo "mv -f $SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT $DESTDIR" 
    mv -f "$SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT" "$DESTDIR"
  else
    echo "OVERWRITE disabled, existing file will not be overwritten"
    if [ $RENAME = 1 ]; then  # RENAME var set, copy file to destination and uniquely identify by appending timestamp to the filename
      echo "RENAME enabled, moving file to destination directory and appending timestamp to file name"
      echo "mv $SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT $DESTDIR/$RLS_NEW_FNAME-$(date +%d%m%y%H%M).$RLS_EXT"
      mv "$SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT" "$DESTDIR/$RLS_NEW_FNAME-$(date +%d%m%y%H%M).$RLS_EXT"
    else
      echo "RENAME disabled, deleting downloaded file"
      echo "rm $SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT"
      rm "$SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT"
    fi
  fi
else # no file found at target location, go ahead and move it
  echo "Moving processed file to : $DESTDIR... "
  echo "mv $SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT $DESTDIR"
  mv "$SABEXTRACTDIR/$RLS_NEW_FNAME.$RLS_EXT" "$DESTDIR"
fi
echo -e "Done\n"

# check if old subdirectory now empty and remove if so
echo -n "Deleting old sub-directory..."
if [ -z "`find $1 -type f`" ]; then
  echo "Empty, deleting"
  echo "rmdir $1"
  rmdir "$1"
else
  echo "Directory not empty!"
fi
echo -e "Done\n"

# call remove from history child process. spawns child process with no-hangup
if [ $CALLCLEANUP = 1 ]; then
  echo "Calling child script to delete entry from SABnzbd history"
  CMDLINE="/bin/bash /opt/sabnzbd/scripts/delfromhist.sh $2 >/dev/null 2>&1"
  echo "CMDLINE: $CMDLINE"
  nohup $CMDLINE > /dev/null 2>&1 &
  echo "Exiting script '$(basename \"${0}\")'"
else
  echo "Not calling clean-up script"
fi

