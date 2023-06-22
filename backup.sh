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

# check if git lfs is installed already
if ! command -v git-lfs &> /dev/null
then
    echo "installing git-lfs"
    brew install git-lfs
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
    echo "lrzip had an error, journal.zip.lrz does not exist"
    exit 1
fi

# load the passkey variable from .env file
source .env

# assign random IV to variable
IV=$(head -c 8 /dev/urandom | xxd -p)

# then encrypt the file using aes-256-cbc
openssl enc -aes-256-cbc -iv $IV -in journal.zip.lrz -out journal.zip.lrz.enc -pass pass:$JOURNAL_ENCRYPTION_KEY

# update the IV variable with the latest iv value in the existing .env file now
# reasoning is that if the script fails, the IV will be the same as the last successful encryption
sed -i '' "s/IV=.*/IV=$IV/" .env

# remove the unencrypted zip files
rm journal.zip
rm journal.zip.lrz

# check if the filesize is greater than 2 gigabytes
FILESIZE=$(stat -f%z "journal.zip.lrz.enc")
if [ $FILESIZE -gt 2147483648 ]; then
    echo "journal.zip.lrz.enc is greater than 2 gigabytes, need to break it up into smaller bits"
    exit 1
fi

# check that the encrypted journal is tracked by git lfs
# grep -q: Runs the grep command silently (without any output), but returns an exit status of 0 if a match is found, and a non-zero status otherwise.
# if ! grep ... line checks if the grep command did not find the pattern (exit status is non-zero).
# If the command returns a non-zero exit status, the script proceeds to the git lfs track "journal.zip.lrz.enc" command, adding the file to Git LFS tracking.
if ! grep -q "journal.zip.lrz.enc filter=lfs diff=lfs merge=lfs -text" .gitattributes; then
    git lfs track "journal.zip.lrz.enc"
fi

# commit and push the encrypted file to git repo, including IV in commit message
git add journal.zip.lrz.enc
git commit -m "$IV"
git push -u origin main
