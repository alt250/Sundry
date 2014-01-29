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

DESTDIR=/mnt/eddie/Stuff2

if [ ! -z $7 ] && [ $7 -gt 0 ]; then
    echo "post-processing failed, bypassing script"
    exit 1
fi

# process files
echo 
echo $(date)
echo "Removing supplimentary files for $1/$3"

# extensions removed:
# .diz
# .nfo
# .url
# .html
# .txt/TXT
# .jpg

# example:
# find "/mnt/user/NG/Unknown" -iname "TopGrl.2011.03.07.Lil.Niki.Nymph.XXX.720p.MP4-hUSHhUSH" -regextype posix-awk -regex "(.*\.nfo|.*\.diz)" -exec echo rm -f {} +

# look for files with extensions as per regex, delete them if found
echo -n "Cleaning extra support files... "
find "$1" -regextype posix-extended -iregex '.*\.(nfo|diz|url|htm|html|jpg|png|txt)' -exec rm -f {} +

echo -e "Done\n"

# rename extracted file to name of parent directory and move to parent directory
echo "Renaming extracted file to name of parent directory... "
while read file
do
  parentdir="$(dirname "$1")"
  directoryname="$(dirname "$file")"
  new_name="${directoryname##*/}"
  file_ext=${file##*.}
  echo "file: $file"
  echo "new_name: $new_name"
  echo "file_ext: $file_ext"  
  echo "parentdir: $parentdir"
  echo "directoryname: $directoryname"
  if [ -n "$file_ext" -a  -n "$directoryname" -a -n "$new_name" ]
  then
    echo "mv $file $parentdir/$new_name.$file_ext"
    mv "$file" "$parentdir/$new_name.$file_ext"
  fi
done < <(find "$1" -maxdepth 1 -type f)
echo -e "Done\n"

# if filename is scene standard and contains XXX, then rename to strip everything after XXX inclusive
echo -n "Checking for Scene Naming Convention... "
if [[ "$new_name" == *.XXX.* ]]; then
  echo "Found"
  oldscenename="$new_name"
  echo "Old Name : $new_name"
  new_name="${oldscenename%.XXX.*}"
  echo "New Name : $new_name"
  echo "mv $parentdir/$oldscenename.$file_ext $parentdir/$new_name.$file_ext"
  mv "$parentdir/$oldscenename.$file_ext" "$parentdir/$new_name.$file_ext"
else
  echo "Not found"
fi
echo -e "Done\n"

# move processed file to dest location
echo "Moving processed file to $DESTDIR... "
src_file_size=$(stat -c%s "$parentdir/$new_name.$file_ext")
#echo "Source File Size = $src_file_size"
if [ -f $DESTDIR/$new_name.$file_ext ]; then # a file already exists at the target location
  echo "Found file with same name at target location.  Checking file size..."
  tgt_file_size=$(stat -c%s "$DESTDIR"/"$new_name"."$file_ext")
  #echo "Target File Size = $src_file_size"
  if [ "$src_file_size" -lt "$tgt_file_size" ]; then # source file is smaller than target
    echo "Source file is smaller than target, I'm going to go ahead and assume its safe to overwrite as we want to keep the smaller non-720p version"
    echo "mv -f $parentdir/$new_name.$file_ext $DESTDIR"
    mv -f "$parentdir/$new_name.$file_ext" "$DESTDIR"
  fi
else # no file found at target location, go ahead and move it
  echo "mv $parentdir/$new_name.$file_ext $DESTDIR"
  mv "$parentdir/$new_name.$file_ext" "$DESTDIR"
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
echo "Calling child script to delete entry from SABnzbd history"
CMDLINE="/bin/bash /opt/sabnzbd/scripts/delfromhist.sh $2 >/dev/null 2>&1"
echo "CMDLINE: $CMDLINE"
nohup $CMDLINE > /dev/null 2>&1 &
echo "Exiting script '$(basename \"${0}\")'"

