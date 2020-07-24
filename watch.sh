#!/bin/bash

OUR_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source_directory=$1
backup_directory=$2

while :
do
   fswatch -1 -n -0 $source_directory | xargs -0 -n 1 -I {} ${OUR_DIRECTORY}/do_copy.sh ${source_directory} ${backup_directory} {}
done

