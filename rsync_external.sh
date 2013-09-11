#!/bin/bash
#
# script to backup multiple directory locations using rsync.  
# defines source, dest, date, temp log variables
# sets trap so temp log file will be deleted even if script is terminated with ctrl-z
# first checks if target backup location exists and if it does not, exits with log entry to syslog and sends email indicating error status
# directory paths to backup are read from file "rsync_include_list".  this removes need for this script to contain possibly changable data
# if rsync exits with non-zero return code, error is logged to syslog and email is sent indicating there was an error
# if rsync exits successfully, compressed tar archive of rsync log is created

# Changelog:
# 08-12-2012 : first draft created
# 09-12-2012 : missed out the rsync --delete parameter option
# 09-12-2012 : changed tar command to use autocompress (-a) option.  enables logfile extention to dictate the compression type
# 09-12-2012 : changed templog to just use script basename.  too complicated, was making multiple tmp files
# 10-12-2012 : added new config vars: verbose (for logging), dryrun (to run rsync in dry-run mode), email to en/disable email error reports
# 11-12-2012 : rsync param change.  removed -r as already implied in -a.  added -h (human readable)
# 11-12-2012 : explictly set LANG=en_US.utf8 prior to rsync
# 12-12-2012 : completely reworked logging: 
#              1. temporary rsync log name is a combination of this script name + this script PID, resulting in unique name per invocation
#              2. final log is created as a compressed tar archive, consisting of a log for each time this script runs where the date remains the same


######################################################################
# DEFINE USER VARIABLES
######################################################################
# set global date var
logdate=$(date +%d-%m-%y)

# define the source location. must end in slash to work correctly
source=/mnt/user/

# define target backup location
target=/mnt/usb/WDExt/Backups

# define rsync include file name / location
rsyncincludes=/boot/scripts/rsync_external_WDExt_include_list

# define log dir
logdir=/mnt/cache/Services/logs

# define log name as composite of static text and logdate variable.  Does NOT need file extenion.  This is added later as ".tar.gz"
logname=rsync_backup_log_"$logdate"

# run rsync in dry-run mode. tells rsync to not do any file transfers, instead it will just report the actions it would have taken.  set to blank "" to disable, "true" to enable
dryrun=""

# verbose logging. set to true to enable logging to syslog and provide level of feedback when running from command line.  set to blank "" to disable, "true" to enable
verbose="true"

# send email. send email if rsync encounters an error.  set to blank "" to disable, "true" to enable
email="true"

#####################################################################
# NO DATA BELOW HERE SHOULD REQUIRE CHANGING 
#####################################################################

# create temp log file for rsync logging process & create trap to remove temp files upon script termination
rsynclog=$(basename "$0")_[$$].log
trap 'rm -f /tmp/$rsynclog' exit

if [ ! -d "$target" ]; then  # test if backup target location exists
  [ "$email" ] && echo -e "Subject: ### $(basename \"$0\") ###\n\nError: target backup location ($target) does not exist!" | ssmtp -d root
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### Error: target backup location ($target) does not exist!"
  exit 1
else
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### started"
  export LANG=en_US.utf8
  if [ "$dryrun" = "true" ]; then
    [ "$verbose" ] && logger -s "### $(basename \"$0\") ### rsync running in dry-run mode, no files will be transferred"
    rsync -avih --dry-run --delete --stats --include-from=$rsyncincludes --exclude=* --log-file=/tmp/"$rsynclog" "$source" "$target"
  else
    rsync -avih --delete --stats --include-from=$rsyncincludes --exclude=* --log-file=/tmp/"$rsynclog" "$source" "$target"
  fi
  # store rsync return code for later
  rc=$? 
  
  if [ ! -f "$logdir/$logname".tar.gz ]; then # destination log does not yet exist, go ahead and tar with creation parameter
    [ "$verbose" ] && logger -s "### $(basename \"$0\") ### Creating LOG Archive : $logdir/$logname.tar.gz with rsync log : $rsynclog"
	tar zcvf "$logdir"/"$logname".tar.gz -C /tmp "$rsynclog" > /dev/null
  else
    # destination log exists, add new rsync log file to existing log archive (wrap in decompress/recompress as tar does not support adding to compressed archive)
    [ "$verbose" ] && logger -s "### $(basename \"$0\") ### Updating Existing LOG Archive : $logdir/$logname.tar.gz with rsync log : $rsynclog"
	gzip -d "$logdir"/"$logname".tar.gz
	tar rf "$logdir"/"$logname".tar -C /tmp "$rsynclog" > /dev/null
	gzip "$logdir"/"$logname".tar
  fi
  # explicity set ownership / permissions on destination log file to nobody / rwxrwx---
  chmod 0770 "$logdir"/"$logname".tar.gz
  chown nobody:users "$logdir"/"$logname".tar.gz
  
  # check rsync return code. report error if not zero and log if config vars are set.
  if [ $rc -gt 0 ]; then
    [ "$email" ] && echo -e "Subject: ### $(basename \"$0\") ###\n\nError: rsync exited with non-zero return code ($rc), please check backup log." | ssmtp -d root
    [ "$verbose" ] && logger -s "### $(basename \"$0\") ### rsync exited with a non-zero return code ($rc), please check backup log"
    #mv "$logdir"/"$logname".tar.gz "$logdir"/!FAILED!_"$logname".tar.gz
	exit 1
  else
    [ "$verbose" ] && logger -s "### $(basename \"$0\") ### finished successfully"
  fi
fi

