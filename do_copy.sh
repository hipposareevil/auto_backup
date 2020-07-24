#!/bin/bash

# Grab params
source_directory=$1
backup_directory=$2
file=$3
base=$(basename $file)


# Set all logging to .copy.log
LOG_FILE=$backup_directory/.copy.log
exec 1>$LOG_FILE
exec 2>&1

# Sync from source directory to backup
echo ""
now=$(date)
echo "[** $now **]"
echo "[Sync files]"
rsync -r --safe-links --exclude-from=$backup_directory/.copyignore $source_directory/ $backup_directory

# Chdir to backup_directory and git add/commit
echo "[Update git]"
cd $backup_directory
git add .
git commit --all -m "Update per file: '$base'"

echo "[Backup complete]"




