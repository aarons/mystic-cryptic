#bin/bash

# this just installs the cronfile
echo "\nInspecting the current crontab:"
crontab -l

# check if journal-backup/backup.sh is already added to the crontab
if crontab -l | grep -q "journal-backup/backup.sh"; then
    echo "\njournal-backup/backup.sh is already in crontab"
    echo "not doing anything, thanks for running setup anyway :)"
    exit 0
fi

echo "\nAdding backup.sh for 10pm every day"
( crontab -l ; echo "0 22 * * * $(pwd)/backup.sh > $(pwd)/backup-log.txt" ) | crontab -

echo "\nNew crontab:"
crontab -l

echo "\nDone"
