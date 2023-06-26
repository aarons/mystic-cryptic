#!/bin/bash

# add a simple logger function
# usage: log "message"
log() {
  echo "$(date) - $1"
}

echo "This script backs up a directory and encrypts it with aes-256-cbc"
echo "It only keeps the latest backup around, previous ones are removed to save space"

dir_path=""
output_path=""
hour=""
file_size_limit=""

# take a directory parameter (-d) as the directory to backup
# -o for the output location
# -h optionally for a time of day to run the backup regularly
# -l optionally specify a file size limit

while getopts ":d:o:h:l:" opt; do
  case $opt in
  d) dir_path="$OPTARG" ;;
  o) output_path="$OPTARG" ;;
  h) backup_hour="$OPTARG" ;;
  l) file_size_limit=$OPTARG ;;
  \?)
    # this is for when an unknown option is provided.
    echo "Invalid option: -$OPTARG" >&2
    echo "This script takes three parameters:"
    echo "-d for the directory to backup (required)"
    echo "-o for the output directory. The filename is created automatically (required)"
    echo "-h for an optional hour of day to run the backup regularly, use 0-23 for the hour (optional)"
    echo "-l for an optional file size limit in KB, files over this size will be excluded from the backup (optional)"
    echo "example: backup -d /path/to/files -o /where/to/put/backup -h 22 -l 100000k"
    echo "this will created an encrypted backup named path_to_files.zip.lrc.enc.<random 8 hex IV> in /where/to/put/backup, and filter out files over 100mb (100000k)"
    exit 1
    ;;
  :)
    # this is for when an option is missing an argument
    echo "Option -$OPTARG requires an argument." >&2
    exit 1
    ;;
  esac
done

if [ -z "$dir_path" ]; then
  echo "Missing -d option. Please provide a directory to backup: 'backup -d /path/to/files -o /where/to/put/backup'" >&2
  exit 1
fi

if [ -z "$output_path" ]; then
  echo "Missing -o option. Please provide an output location: 'backup -d /path/to/files -o /where/to/put/backup'" >&2
  exit 1
fi

# create the output filename by using the directory name
file_name=${dir_path#/} # remove leading slash if present
file_name=${file_name%/} # remove trailing slash if present
file_name=$(echo "$file_name" | sed 's/[^[:alnum:]]/-/g') # replace non-alphanumeric characters with dashes
file_name=$(echo "$file_name" | tr '[:upper:]' '[:lower:]') # make file name lowercase

# make sure work is done in the temp directory
log "backing up: $dir_path"
log "writing temporarily to: $(pwd)/temp/$file_name.zip"
log "will store encrypted backup in $output_path when done"

# load the encryption key from .env file
source ".env"

# check if ENCRYPTION_KEY parameter is set
if [ -z "$ENCRYPTION_KEY" ]; then
  log "Missing ENCRYPTION_KEY in either the environment, or .env file"
  log "Please add ENCRYPTION_KEY='your encryption key' to the .env file"
  log "Be sure to save the key somewhere safe as the files won't be recoverable without it"
  exit 1
fi

cd $(pwd)/temp
zip_arguments="--quiet --test --recurse-paths -0 $file_name \"$dir_path\""

# check if file size limit was specified
if [ ! -z "$file_size_limit" ]; then
  log "file size limit specified, will exclude files over $file_size_limit"
  find "$dir_path" -type f -size +$file_size_limit > $filename.exclusions.txt

  log "Here's the list of excluded files:"
  cat $filename.exclusions.txt | while read line; do
    log "$line"
  done
  zip_arguments="$zip_arguments -x@$filename.exclusions.txt"
fi

# zip the directory
log "running zip with: zip $zip_arguments"
log "temporary output file is $file_name.zip"
eval zip $zip_arguments

# remove exclusions file if it exists
if [ -f $filename.exclusions.txt ]; then
  rm $filename.exclusions.txt
fi

# stop if there was an issue creating the zip file
if [ ! -f $file_name.zip ]; then
  log "$file_name.zip does not exist, something went wrong at the zip stage"
  exit 1
fi

log "lrzip running next:"

# use lrzip to compress the zip file
# -L 9 is the highest compression level
# lrzip depends on the file not existing, so we need to remove it first if it was there from an old run
if [ -f $file_name.zip.lrz ]; then
  rm $file_name.zip.lrz
fi

lrzip -L 9 $file_name.zip

# check if the file was created
if [ ! -f $file_name.zip.lrz ]; then
  log "lrzip had an error, journal.zip.lrz does not exist"
  exit 1
fi

# assign random IV to variable
IV=$(head -c 8 /dev/urandom | xxd -p)

# then encrypt the file using aes-256-cbc
openssl enc -aes-256-cbc -iv $IV -in $file_name.zip.lrz -out $file_name.zip.lrz.enc.$IV -pass pass:$ENCRYPTION_KEY

# check if the file was created
if [ ! -f $file_name.zip.lrz.enc.$IV ]; then
  log "openssl had an error, $file_name.zip.lrz.enc.$IV does not exist"
  exit 1
fi
log "encrypted file with IV: $IV"

# rename the old backup if it exists
old_backups=$(find "$output_path" -type f -name "$file_name.zip.lrz.enc.*")
if [ ! -z "$old_backups" ]; then
  while read -r old_backup; do
    log "found previous backup, renaming to $old_backup.old"
    mv "$old_backup" "$old_backup.old"
  done <<< "$old_backups"
fi

# move the new encrypted file to the output directory
mv $file_name.zip.lrz.enc.$IV "$output_path"

# check that it's there
if [ ! -f "$output_path/$file_name.zip.lrz.enc.$IV" ]; then
  log "$output_path/$file_name.zip.lrz.enc.$IV does not exist, something went wrong"
  log "the previous output is still there, with the .old extension"
  exit 1
fi
log "moved encrypted file to $output_path/$file_name.zip.lrz.enc.$IV"

# remove old backups
if [ ! -z "$old_backups" ]; then
  while read -r old_backup; do
    log "removing old backups $old_backup.old"
    rm "$old_backup.old"
  done <<< "$old_backups"
fi

# remove temprory files
temp_files=$(find "." -type f -name "$file_name.*")
if [ ! -z "$temp_files" ]; then
  while read -r temp_file; do
    log "removing temporary file: $temp_file"
    rm $temp_file
  done <<< "$temp_files"
fi

# This is the function for scheduling backups (if needed)
schedule_cronjob() {
  log "\nInspecting the current crontab:"
  crontab -l
  # note that the script was running in it's temp directory, so back out to the base directory
  cd ../ # there is probably a better way to do this
  base_path=$(pwd)
  script_name="backup.sh"

  # check if journal-backup/backup.sh is already added to the crontab
  cron_str="0 $backup_hour * * * cd $base_path && ./$script_name -d \"$dir_path\" -o \"$output_path\""

  # check if file_size_limit is specified and add to cron_str if so
  if [ ! -z "$file_size_limit" ]; then
    cron_str="$cron_str -l $file_size_limit"
  fi

  log "checking if crontab has: $cron_str"
  if crontab -l | grep -q -F "$cron_str"; then
    log "\nbackup.sh is already scheduled"
    log "not doing anything to avoid duplicate schedules"
    exit 0
  fi

  # check if /usr/bin and /bin are available in cron
  if ! crontab -l | grep -q "[:/usr/bin|:/bin]"; then
    if crontab -l | grep -q "^PATH="; then
      # path already exists, just add to it
      crontab -l | sed 's/\(PATH=.*\)/\1:\/usr\/bin/:\/bin/' | crontab -
    else
      (
        echo "PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        crontab -l 2>/dev/null
      ) | crontab -
    fi
    log "/usr/bin was not available in cron, added it so that lrzip and zip will function"
  fi

  log "\nAdding backup.sh for hour of the day: $backup_hour"
  (
    crontab -l 2>/dev/null
    echo "$cron_str >> $(pwd)/logs/log.txt"
  ) | crontab -

  log "\nNew crontab:"
  crontab -l
}

# check if the backup_hour parameter is set and that it is an integer between 0 and 23
# if it's set, then run the schedule_cronjob function
# I find bash comparisons a little hard to parse, particularly the second one, so here are the deets:
# ! -z "$backup_hour" checks if the $backup_hour variable is not empty.
# "$backup_hour" -eq "$backup_hour" 2>/dev/null checks if $backup_hour is an integer.
#     By running a comparison between $backup_hour and itself and redirecting any error messages to /dev/null,
#     the condition will only be true if the input is an integer, otherwise it will produce an error.
# "$backup_hour" -ge 0 checks if the $backup_hour variable is greater than or equal to 0.
# "$backup_hour" -le 23 checks if the $backup_hour variable is less than or equal to 23.
if [ ! -z "$backup_hour" ] && [ "$backup_hour" -eq "$backup_hour" ] 2>/dev/null && [ "$backup_hour" -ge 0 ] && [ "$backup_hour" -le 23 ]; then
  schedule_cronjob
else
  log "\nNo backup hour provided, not scheduling a regular backup"
fi

# trim the logfile if its gotten really long
if [ -f "logs/log.txt" ]; then
  log_size=$(wc -c <"logs/log.txt")
  if [ $log_size -gt 1000000 ]; then
    log "trimming 100kb from the 1mb log.txt file, so that it doesn't grow too large"
    tail -c 900000 "logs/log.txt" > "logs/temp-log.txt"
    mv "logs/temp-log.txt" "logs/log.txt"
  fi
fi

log "\nBackup and encryption complete"
