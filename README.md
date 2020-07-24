# Introduction

This is a utility to perform automatic backups of all files in a given directory (and child directories). It's an poor mans version of filesystem versioning for files.

When running, this will monitor all files in a directory, and when one changes - that file is copied to a backup directory and committed to a git repository.

# Prerequisites

Install these:

* [fswatch](https://github.com/emcrisostomo/fswatch)
* [git](https://git-scm.com/downloads)

# Installation

### 1. Clone or download this repo and add to your $PATH.


    $ git clone https://github.com/hipposareevil/auto_backup.git
    $ cd auto_backup
    $ export PATH=$PATH:$PWD
    // or put into your .zshrc
    $ echo "$PATH=$PATH:$PWD >> ~/.zshrc"

### 2. Determine where to save your backups and set environment variable:
This will default to /tmp/auto_backup.


    $ export BACKUP_ROOT_DIRECTORY=/mywork/backups
    // or put into .zshrc
    $ echo "export BACKUP_ROOT_DIRECTORY=/mywork/backups" >> ~/.zshrc

### 3. Initialize your backup


    $ cd /backup/this/awesome
    $ hippowatch.sh --init
    [Initialize backups in: /mywork/backups/awesome.57293790]
    [No git install. Creating]
    [Created]
    [Initial copy complete]
    [Added to git]
    [Commited to git]


# Usage

After initializing the backup, you can start, stop, or get status of the backup.

### 1. Start the automatic backup


    $ hippowatch.sh --start
    [Starting process to backup '/backup/this/awesome']
    [Backup running in pid 48692]

### 2. Get status


    $ hippowatch.sh --status
    [Backup for '/backup/this/awesome' is running (54999)]

### 3. Stop the automatic backup 


    $ hippowatch.sh --stop
    [Backup stopped (48692)]


### 4. Example of looking at backups


    $ pwd
    /backup/this/awesome
    $ hippowatch.sh --start
    ...
    $ echo "first entry" > some.file
    // .backup_directory is soft link to the backup directory
    // You could also just cd to /mywork/backups/awesome.57293790
    $ cd .backup_directory
    $ git log -p
    commit 8cbda20287c01c23e333312a28d61867c23794a7 (HEAD -> master)
    Author: YOU <your.email@gmail.com>
    Date:   Thu Jul 23 21:01:34 2020 -0700

    Update per file: 'some.file'

    diff --git a/some.file b/some.file
    new file mode 100644
    index 0000000..257cc56
    --- /dev/null
    +++ b/some.file
    @@ -0,0 +1 @@
    +first entry
    // go back
    $ cd -



# Details

1. When the initialization is done, a backup directory with the same name as the root of your source directory is created. This name has the inode id attached, to distinguish betwen multiple backups of the same named source directory.

2. Git will be running locally for each directory that is being backed up.

3. Logs of the activity go into the backup directory under the file `.copy.log`


# zsh theme

If you're using zsh and [oh-my-zsh](https://ohmyz.sh/), you can add the following snippet to your PROMPT. You will need unicode enabled iterm2 for this to look good.

[snippet]()

