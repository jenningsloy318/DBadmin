#!/bin/bash
# define backup prefix
TIMESTAMP="$(date +%Y%m%H%M%S)"
BACKUP_PREFIX="FULLBACKUP"
BACKUP_PREFIX="$BACKUP_PREFIX"_"$TIMESTAMP"
# source HANA environment
. /usr/sap/shared/DB1/HDB01/hdbenv.sh
# execute command with user key
# asynchronous runs job in background and returns prompt
hdbsql -U backup "backup data using file ('$BACKUP_PREFIX') ASYNCHRONOUS"

