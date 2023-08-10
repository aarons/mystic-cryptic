#!/bin/bash

# this depends on a filename parameter
# it will decrypt the file using the passkey in .env or ENCRYPTION_KEY env variable
# it will then decompress the file using lrzip

full_path=""
output_dir=""

while getopts ":f:o:" opt; do
  case $opt in
  f) full_path="$OPTARG" ;;
  o) output_dir="$OPTARG" ;;
  \?)
    # this is for when an unknown option is provided.
    echo "Invalid option: -$OPTARG" >&2
    echo "This script takes two parameters:"
    echo "-f for the file to decrypt and decompress (required)"
    echo "-o for the output directory. The filename is created automatically (required)"
    echo "example: restore -f /path/to/files.zip.lrz.enc.12345678 -o /where/to/put/backup"
    exit 1
    ;;
  :)
    # this is for when an option is missing an argument
    echo "Option -$OPTARG requires an argument." >&2
    exit 1
    ;;
  esac
done

if [ -z "$full_path" ]; then
  echo "Missing -f option. Please provide a file to decrypt and decompress: 'restore -f /path/to/files.zip.lrz.enc.12345678 -o /where/to/put/backup'" >&2
  exit 1
fi

if [ -z "$output_dir" ]; then
  echo "Missing -o option. Please provide an output location: 'restore -f /path/to/files.zip.lrz.enc.12345678 -o /where/to/put/backup'" >&2
  exit 1
fi

# check that the output dir exists
if [ ! -d "$output_dir" ]; then
  echo "Output directory does not exist: $output_dir, creating:" >&2
  mkdir -p "$output_dir"
fi

# ensure that output_dir does not end with a '/'
output_dir=${output_dir%/}

# get the filename from the full path
filename=$(basename "$full_path")

# get the filename without any extension:
base_filename=$(echo "$filename" | cut -d. -f1)

echo "filename is: $filename"
echo "filename without extension is: $base_filename"

# Load the encryption key from the .env file
source ".env"

# Extract the IV from the filename
IV="${filename##*.}"

# check if the IV variable is empty
if [ -z "$IV" ]; then
    echo "IV variable is empty and it shouuuuldn't be"
    echo "It's expected the IV value is in the filename: <filename>.<IV>"
    exit 1
fi

# check if the encryption key variable is empty
if [ -z "$ENCRYPTION_KEY" ]; then
    echo "ENCRYPTION_KEY variable is empty"
    echo "Either set it as an environment variable, or add it to the .env file"
    echo "Example: ENCRYPTION_KEY=1234567890abcdef1234567890abcdef"
    exit 1
fi

echo "Using IV: $IV"

# Decrypt the file using aes-256-cbc
decrypted_full_path="${output_dir}/${base_filename}.zip.lrz"

openssl enc -aes-256-cbc -d -iv $IV -in "$full_path" -out "$decrypted_full_path" -pass pass:"$ENCRYPTION_KEY" -pbkdf2 -iter 10

# Decompress the file using lrzip
lrzip -d "${decrypted_full_path}" -o "${output_dir}/${base_filename}.zip"

# Remove the decrypted lrzip file
rm "${decrypted_full_path}"

echo "Decryption and decompression complete."
echo "Restored file: ${output_dir}/${base_filename}.zip"
