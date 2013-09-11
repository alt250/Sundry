#!/bin/bash

# MySQL root data directory
DBDIR=/var/lib/mysql

# MySQL root user name
DBUSER=root

# MySQL root password
DBPASS=password

# Target Backup Location (directory)
BACKUPDIR=/mnt/data/Backups/XBMC

# Target Backup Filename
BACKUPNAME=Benson.MySQL.DB-$(date +%Y-%m-%d);

# Temp directory for mysqldump command and to consolidate all databases into gzip to final backup location
TEMPDIR=$(mktemp -d /tmp/xbmc.XXXXXXXX)

echo "Starting MySQL Database Backup"

pushd $DBDIR >>/dev/null
for DATABASE in * ; do
  if [ -d "$DATABASE" ]; then
    if [ "$DATABASE" != "performance_schema" ]; then  # skip performance_schema dir
      echo "Dumping Database: $DATABASE"
      mysqldump -u $DBUSER -p$DBPASS $DATABASE --routines --events > $TEMPDIR/$DATABASE.sql
    else
      echo Skipping DB backup for performance_schema
    fi
  fi
done
popd >> /dev/null

pushd $TEMPDIR >> /dev/null
tar zcvf "$BACKUPDIR"/"$BACKUPNAME".tar.gz * >> /dev/null
popd >> /dev/null

# Remove temp dir
rm -rf $TEMPDIR

echo "Completed MySQL Database Backup"
