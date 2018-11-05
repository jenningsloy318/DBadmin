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


## restore opertation much be running under <sid>adm
## restore operation can be running via hana studio


## restore to from a backup file
HDBSettings.sh python recoverSys.py --command="RECOVER DATA USING  FILE ('/data/hana/backup/SP6/data/2018-10-07_00-00') CLEAR LOG"

## restore to a time point
HDBSettings.sh python recoverSys.py --command="RECOVER DATABASE UNTIL TIMESTAMP '2018-10-08 00:00:00'  CLEAR LOG "
