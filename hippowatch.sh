#!/bin/bash

#################################
# Utility to backup all file changes.
#
# Environment variable overrides:
# * BACKUP_ROOT_DIRECTORY  - Where to store backups
# * SOURCE_DIRECTORY       - Directory to back up
#################################

########
# Initialize
#
########
initialize_variables() {
    # location of our scripts
    OUR_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

    # where to backup to
    backup_root_directory=${BACKUP_ROOT_DIRECTORY:-"/tmp/auto_backup/"}
    backup_root_directory="${backup_root_directory}/"
    
    # what directory to back up
    source_directory="${SOURCE_DIRECTORY:-$PWD}"

    # If we are in subdirectory of actual source, find the root of the source
    # e.g. look for the .backup.directory soft link
    temp=$(_find_source_root $source_directory)
    if [ ! -z "$temp" ]; then
        source_directory=$temp
    fi 

    # id of source directory
    directory_id=$(ls -id $source_directory | awk '{print $1}')

    # name of backup
    backup_name=$(basename $source_directory)

    # Subdirectory to put backups
    backup_directory="${backup_root_directory}${backup_name}.${directory_id}"

    # link from source to backup dir
    backup_directory_soft_link="${source_directory}/.backup.directory"

    # pid file
    pid_file="${backup_directory}/.pid"

    # log file
    log_file=$backup_directory/.copy.log

    # validate git and fswatch
    result=$(which git)
    if [ $? -ne 0 ]; then
        "Must install git."
        "> brew install git"
        "exiting."
        exit 1
    fi

    result=$(which fswatch)
    if [ $? -ne 0 ]; then
        "Must install fswatch."
        "> brew install fswatch"
        "exiting."
        exit 1
    fi
}

########
# Usage
#
########
usage() {
    name=$(basename $0)
    echo "$name"
    echo "Utility program to backup all file changes in current directory ($backup_name)."
    echo "Backups made to '${backup_root_directory}'"
    echo ""
    echo "Usage:"
    echo "$name [OPTION]"
    echo ""
    echo "Options:"
    echo " --init      Creates backup directory and git infrastructure."
    echo " --start     Start the backup processing."
    echo " --stop      Stop the backup processing."
    echo " --satus     Determines if the backup is processing."
    echo ""
    echo "qed"

    exit 1
}


########
# log
#
########
log() {
    echo "[$@]"
}

# Find the real source root
_find_source_root() {
    source=$1
    what_to_find=".backup.directory"

    path=$source
    while [[ "$path" != "" && ! -e "$path/$what_to_find" ]]; do
        path=${path%/*}
    done
    echo "$path"
}



########
# Return:
# 1 if backups have been initialized
# 0 if no backup directory
########
_is_initialized() {
    if [ -e $backup_directory_soft_link/.git ]; then
        return 1
    else
        return 0
    fi
}

########
# init
#
########
init_backup() {
    result=$(_is_initialized)
    if [ $? -eq 1 ]; then
        log "Already initialized"
        exit 1
    fi

    log "Initialize backups in: $backup_directory"

    # Make directory
    mkdir -p $backup_directory

    echo "$source_directory" > ${backup_directory}/.source.directory

    # Is git repo there?
    result=$(git --git-dir=${backup_directory}/.git rev-parse  >/dev/null 2>&1)

    # Create git and do sync
    if [ $? -eq 0 ]; then
        log "Git install exists. Skipping" 
    else 
        _create_git
        _sync_to_backup
        _add_to_git
        _create_softlink
    fi
}

# Create soft link to backup directory
_create_softlink() {
    /bin/rm -f "${backup_directory_soft_link}"
    ln -s ${backup_directory} ${backup_directory_soft_link}
}

# Create git install
_create_git() {
    log "No git install. Creating"
    result=$(git init $backup_directory)
    log "Created"

    # Create ignore file
read -d '' IGNORE <<EOF
.backup.directory
.class
.copy.log
.copyignore
.git
.pid
.source.directory
.gitignore
.git*
*~
\#*\#
*.class
.bin
*.pyc
*.log
log
logs
.DS_Store
rebel.xml
# Idea specific
.idea/
.idea_modules/
*.iml
*.ipr
*.iws
.cache/
.history/
.lib/
dist/*
target/
lib_managed/
src_managed/
project/boot/
project/plugins/project/
newrelic.jar
newrelic.license
*.tokens%
.env
local-values.yaml*
*.tgz
**/.idea/*

*.DS_Store
.AppleDouble
.LSOverride
chart_dirs
changed_dirs
changed_chart_dirs
EOF

    # create ignore files
    echo "$IGNORE" > $backup_directory/.copyignore
    echo "$IGNORE" > $backup_directory/.gitignore
}

# initial sync to backup dir
_sync_to_backup() {
    # sync everything over
    result=$(rsync -rv --safe-links --exclude-from=$backup_directory/.copyignore $source_directory/ $backup_directory)
    if [ $? -eq 0 ]; then
        log "Initial copy complete"
    else
        log "Initial copy failed:"
        echo "$result"
        exit 1
    fi
}

# Add files to git
_add_to_git() {
    orig_pwd=$PWD
    cd $backup_directory

    # if directory is empty, do nothing
    if [ -z "$(ls -A $source_directory)" ]; then
        log "Empty source directory, skipping git add"
    else
        # add
        result=$(git add .)
        if [ $? -eq 0 ]; then
            log "Added to git"
        else
            log "Failed to add to git"
            echo "$result"
            exit 1
        fi

        # commit
        result=$(git commit --all -m "Initial backup of '${backup_name}' from '${source_directory}'")
        if [ $? -eq 0 ]; then
            log "Commited to git"
        else
            log "Failed to commit"
            echo "$result"
            exit 1
        fi

    fi

    cd $orig_pwd
}


########
# start
#
########
start() {
    # initialized?
    result=$(_is_initialized)
    if [ $? -eq 0 ]; then
        log "Not initialized"
        echo "Please run:"
        echo "$0 --init"
        exit 1
    fi

    # check status
    result=$(status)
    running=$? # 0 = running, 1 down

    if [ $running -eq 0 ]; then
        # Get pid for logging
        if [ -e $pid_file ]; then
            pid=$(cat $pid_file)
        fi

        log "Backup is already running in pid $pid"
        exit 0
    fi

    log "Starting process to backup '${source_directory}'"

    # Start watching program & get pid
    $OUR_DIRECTORY/watch.sh $source_directory $backup_directory &
    pid=$!

    # save pid
    echo "$pid" > $pid_file
    log "Backup running in pid ${pid}"
}


########
# status
#
# exits with 1 when stopped
# exits with 0 when running
########
status() {
    # check pid and if processes are running
    if [ -e $pid_file ]; then
        # pid exists
        pid=$(cat $pid_file)
        result=$(ps -elf | grep $pid | grep -v grep | wc -l)
        return_code=$?

        if [ $result == "0" ]; then
            log "Backup for '$source_directory' is stopped ($pid)"
            rm $pid_file
            exit 1
        else
            log "Backup for '$source_directory' is running ($pid)"
            exit 0
        fi
    else
        # not running
        if [ -e ${backup_directory_soft_link}/.pid ]; then
            log "Backup for '$source_directory' is stopped. (no pidfile)"
        else
            log "No backup configured for '$source_directory'"
        fi

        exit 1
    fi
}


########
# stop
#
########
stop() {
    # initialized?
    result=$(_is_initialized)
    if [ $? -eq 0 ]; then
        log "Backup is not initialized"
        exit 1
    fi

    result=$(status)
    running=$? # 0 = running, 1 down

    if [ $running -eq 1 ]; then
        log "Backup is stopped"
        exit 0
    fi

    if [ -e $pid_file ]; then
        pid=$(cat $pid_file)

        # Get children pids
        children=$(pgrep -P $pid)
        result=$(kill -9 $pid $children)
        if [ $? -eq 0 ]; then
            log "Backup stopped ($pid)"
            rm $pid_file
        else
            log "Backup failed to stop.  PID '$pid'"
        fi
    else
        log "No pid file: $pid_file"
    fi
}




########
# Main
#
########
main() {
    initialize_variables

    if [ $# -eq 0 ]
    then
        usage
    fi

    for arg in $@
    do
        case $arg in
            "-h"|"--help")
                usage
                ;;
            "--init")
                init_backup
                ;;
            "--start")
                start
                ;;
            "--stop")
                stop
                ;;
            "--status")
                status
                ;;
            *)
                usage
        esac
    done


}

main "$@"


