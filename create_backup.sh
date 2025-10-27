#!/bin/bash
# run as: scripts/backup_fs .
# this script generates a tgz file with the db dump, user uploads and site config

# first argument when calling the script should be the dir of loomio-deploy
SOURCE_DIR=$1

# this number specifies how many days to retain backups on disk
BACKUP_RETENTION_DAYS=1

BACKUP_DIR=$SOURCE_DIR/backups
DAY_OF_MONTH=`date '+%-d'`
MOD_DAYS=$(($DAY_OF_MONTH % $BACKUP_RETENTION_DAYS))
DEST_FILE=$BACKUP_DIR/`hostname`-$MOD_DAYS.tgz

echo "writing database dump: /pgdumps/loomio_production.dump"
docker exec loomio-db su - postgres -c 'pg_dump -O -Fc loomio_production -f /pgdumps/loomio_production.dump'

echo "writing backup file: $DEST_FILE"
mkdir -p $BACKUP_DIR
tar cvzf $DEST_FILE -X $SOURCE_DIR/.backup-ignore $SOURCE_DIR
