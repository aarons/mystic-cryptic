#!/bin/bash

cd /Users/aaron/code/services/journal-backup

# check if the lrzip command is installed already
if ! command -v lrzip &> /dev/null
then
    echo "installing lrzip"
    brew install lrzip
fi

if ! command -v lrzip &> /dev/null
then
    echo "lrzip could not be found"
    exit 1
fi

# first zip the ~/Documents/journal directory
zip --display-counts --test --recurse-paths -0 journal.zip /Users/aaron/Documents/journal

# stop if there was an issue creating the file
if [ ! -f journal.zip ]; then
    echo "journal.zip does not exist"
    exit 1
fi

# use lrzip to compress the zip file
# -L 9 is the highest compression level
lrzip -L 9 journal.zip

if [ ! -f journal.zip.lrz ]; then
    echo "journal.zip.lrz does not exist"
    exit 1
fi

# load the passkey variable from .env file
source .env

# then encrypt the file using aes-256-cbc
openssl enc -aes-256-cbc -in journal.zip.lrz -out journal.zip.lrz.enc -pass pass:$JOURNAL_ENCRYPTION_KEY

# remove the unencrypted zip files
rm journal.zip
rm journal.zip.lrz

# check if the filesize is greater than 2 gigabytes
FILESIZE=$(stat -f%z "journal.zip.lrz.enc")
if [ $FILESIZE -gt 2147483648 ]; then
    echo "journal.zip.lrz.enc is greater than 2 gigabytes"
    exit 1
fi

# make sure the file is tracked by git lfs
git lfs track "journal.zip.lrz.enc"

# commit and push the encrypted file to git repo, including date in commit message
git add journal.zip.lrz.enc
git commit -m "journal backup $(date +%Y-%m-%d)"
git push -u origin main
