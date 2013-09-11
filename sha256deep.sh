#!/bin/bash
#
# script to calculate sha256 hashes of all files
# is expected to be run from cron where current day number is used to determine which disk{x} to check.  ie. on day 1 it will check /mnt/disk1
# if there is no corresponding disk[x] for current day, no action is taken

# Changelog:
# 01-08-2013 : first draft created


######################################################################
# DEFINE USER VARIABLES
######################################################################
# set global date var
logdate=$(date +%d-%m-%y)

# define log dir
logdir=/mnt/cache/Services/logs

# define log name as composite of static text and logdate variable.  Does NOT need file extenion.  This is added later as ".tar.gz"
logname=sha256deep_log_"$logdate"

# verbose logging. set to true to enable logging to syslog and provide level of feedback when running from command line.  set to blank "" to disable, "true" to enable
verbose="true"

#####################################################################
# NO DATA BELOW HERE SHOULD REQUIRE CHANGING 
#####################################################################

# create temp log file for logging & create trap to remove temp file upon script termination
shalog=$(basename "$0")_[$$].log
trap 'rm -f /tmp/$rsynclog' exit

# determine day as number
DD=$(date "+%e"|sed -e 's# ##g')

logger "SHA256 Hash Script Starting..."
if [ ! -e /mnt/disk${DD} ]; then
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### Disk${DD} not found, SHA256 Hash Script Stopping"
  exit 1
else
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### started"
  /usr/local/bin/sha256deep -r /mnt/disk${DD} > /tmp/"$shalog"
  # store return code for later
  rc=$?
fi

if [ ! -f "$logdir/$logname".tar.gz ]; then # destination log does not yet exist, go ahead and tar with creation parameter
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### Creating LOG Archive : $logdir/$logname.tar.gz with sha256deep log : $shalog"
  tar zcvf "$logdir"/"$logname".tar.gz -C /tmp "$shalog" > /dev/null
else
  # destination log exists, add new sha256deep log file to existing log archive (wrap in decompress/recompress as tar does not support adding to compressed archive)
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### Updating Existing LOG Archive : $logdir/$logname.tar.gz with sha256deep log : $shalog"
  gzip -d "$logdir"/"$logname".tar.gz
  tar rf "$logdir"/"$logname".tar -C /tmp "$shalog" > /dev/null
  gzip "$logdir"/"$logname".tar
fi
# explicity set ownership / permissions on destination log file to nobody / rwxrwxrwx
chmod 0777 "$logdir"/"$logname".tar.gz
chown nobody:users "$logdir"/"$logname".tar.gz

# check sha256deep return code. report error if not zero and log if config vars are set.
if [ $rc -gt 0 ]; then
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### sha256deep exited with a non-zero return code ($rc), please check log"
  exit 1
else
  [ "$verbose" ] && logger -s "### $(basename \"$0\") ### finished successfully"
fi
