#!/bin/bash

echo "This script backs up a directory and encrypts it with aes-256-cbc"
echo "It only keeps the latest backup around, previous ones are removed to save space"

dir_path=""
output_path=""
hour=""

# take a directory parameter (-d) as the directory to backup
# -o for the output location
# -h optionally for a time of day to run the backup regularly
while getopts ":d:o:h:" opt; do
  case $opt in
  d) dir_path="$OPTARG" ;;
  o) output_path="$OPTARG" ;;
  h) backup_hour="$OPTARG" ;;
  \?)
    # this is for when an unknown option is provided.
    echo "Invalid option: -$OPTARG" >&2
    echo "This script takes three parameters:"
    echo "-d for the directory to backup (required)"
    echo "-o for the output directory. The filename is created automatically (required)"
    echo "-h for an optional hour of day to run the backup regularly, use 0-23 for the hour (optional)"
    echo "example: backup -d /path/to/files -o /where/to/put/backup -h 22"
    echo "this will created an encrypted backup named path_to_files.zip.lrc.enc.<random 8 hex IV> in /where/to/put/backup"
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

# check if zip and lrzip is installed
if ! command -v lrzip &>/dev/null; then
  echo "This program relies on lrzip, please install before continuing."
  echo "Suggest running: 'brew install lrzip' if you are on a mac"
  echo "homebrew can be install by running: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# check if zip and lrzip is installed
if ! command -v zip &>/dev/null; then
  echo "This program relies on zip, please install before continuing."
  echo "This is normally included with a mac, not sure how you get to this point..."
  echo "Please be sure zip is available in your shell path (maybe check the output of 'echo \$PATH', and your bash profile in one of these files: .bashrc, .zshrc, .bash_profile, or .zprofile)"
  exit 1
fi

# create the output filename by using the directory name
file_name=${dir_path#/} # remove leading slash if present
file_name=$(echo "$file_name" | tr '/' '-')
file_name=$(echo "$file_name" | tr '[:upper:]' '[:lower:]') # replace slashes with dashes, and make lowercase

# make sure work is done in the temp directory
echo "backing up: $dir_path"
echo "writing temporarily to: $(pwd)/temp/$file_name.zip"
echo "will store encrypted backup in $output_path when done"

# first zip the directory
cd $(pwd)/temp
zip --quiet --test --recurse-paths -0 $file_name $dir_path

# stop if there was an issue creating the file
if [ ! -f $file_name.zip ]; then
  echo "$file_name.zip does not exist, something went wrong at the zip stage"
  exit 1
fi

# use lrzip to compress the zip file
# -L 9 is the highest compression level
# lrzip depends on the file not existing, so we need to remove it first if it was there from an old run
if [ -f $file_name.zip.lrz ]; then
  rm $file_name.zip.lrz
fi

lrzip -L 9 $file_name.zip

# check if the file was created
if [ ! -f $file_name.zip.lrz ]; then
  echo "lrzip had an error, journal.zip.lrz does not exist"
  exit 1
fi

# load the encryption key from .env file
source "../.env"

# check if ENCRYPTION_KEY parameter is set
if [ -z "$ENCRYPTION_KEY" ]; then
  echo "Missing ENCRYPTION_KEY in either the environment, or .env file"
  echo "Please add ENCRYPTION_KEY='your encryption key' to the .env file"
  echo "Be sure to save the key somewhere safe as the files won't be recoverable without it"
  exit 1
fi

# assign random IV to variable
IV=$(head -c 8 /dev/urandom | xxd -p)

# then encrypt the file using aes-256-cbc
openssl enc -aes-256-cbc -iv $IV -in $file_name.zip.lrz -out $file_name.zip.lrz.enc.$IV -pass pass:$ENCRYPTION_KEY

# check if the file was created
if [ ! -f $file_name.zip.lrz.enc.$IV ]; then
  echo "openssl had an error, $file_name.zip.lrz.enc.$IV does not exist"
  exit 1
fi
echo "encrypted file with IV: $IV"

# rename the old backup if it exists
old_backups=$(find "$output_path" -type f -name "$file_name.zip.lrz.enc.*")
if [ ! -z "$old_backups" ]; then
  while read -r old_backup; do
    echo "found previous backup, renaming to $old_backup.old"
    mv "$old_backup" "$old_backup.old"
  done <<< "$old_backups"
fi

# move the new encrypted file to the output directory
mv $file_name.zip.lrz.enc.$IV "$output_path"

# check that it's there
if [ ! -f "$output_path/$file_name.zip.lrz.enc.$IV" ]; then
  echo "$output_path/$file_name.zip.lrz.enc.$IV does not exist, something went wrong"
  echo "the previous output is still there, with the .old extension"
  exit 1
fi
echo "moved encrypted file to $output_path/$file_name.zip.lrz.enc.$IV"

# remove old backups
if [ ! -z "$old_backups" ]; then
  while read -r old_backup; do
    echo "removing old backups $old_backup.old"
    rm "$old_backup.old"
  done <<< "$old_backups"
fi

# remove temprory files
temp_files=$(find "." -type f -name "$file_name.*")
if [ ! -z "$temp_files" ]; then
  while read -r temp_file; do
    echo "removing temporary file: $temp_file"
    rm $temp_file
  done <<< "$temp_files"
fi

# This is the function for scheduling backups (if needed)
schedule_cronjob() {
  echo "\nInspecting the current crontab:"
  crontab -l
  # note that the script was running in it's temp directory, so back out to the base directory
  cd ../ # there is probably a better way to do this
  script_path="$(pwd)/$(basename "$0")"
  # check if journal-backup/backup.sh is already added to the crontab
  cron_str="0 $backup_hour * * * $script_path -d \"$dir_path\" -o \"$output_path\""
  echo "checking if crontab has: $cron_str"
  if crontab -l | grep -q -F "$cron_str"; then
    echo "\nbackup.sh is already scheduled"
    echo "not doing anything to avoid duplicate schedules"
    exit 0
  fi

  # check if /usr/bin is available in cron
  if ! crontab -l | grep -q "/usr/bin"; then
    if crontab -l | grep -q "PATH="; then
      crontab -l | sed 's/\(PATH=.*\)/\1:\/usr\/bin/' | crontab -
    else
      (
        echo "PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        crontab -l 2>/dev/null
      ) | crontab -
    fi
    echo "\n/usr/bin was not available in cron, added it so that lrzip and zip will function"
  fi

  echo "\nAdding backup.sh for hour of the day: $backup_hour"
  (
    crontab -l 2>/dev/null
    echo "0 $backup_hour * * * $script_path -d \"$dir_path\" -o \"$output_path\" > $(pwd)/logs/log.txt"
  ) | crontab -

  echo "\nNew crontab:"
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
  echo "\nNo backup hour provided, not scheduling a regular backup"
fi

# trim the logfile if its gotten really long
if [ -f "logs/log.txt" ]; then
  log_size=$(wc -c <"logs/log.txt")
  if [ $log_size -gt 1000000 ]; then
    echo "trimming 100kb from the 1mb log.txt file, so that it doesn't grow too large"
    tail -c 900000 "logs/log.txt" > "logs/temp-log.txt"
    mv "logs/temp-log.txt" "logs/log.txt"
  fi
fi

echo "\nBackup and encryption complete"
