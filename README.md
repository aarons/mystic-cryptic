# Backup and Encrypt Script

This program provides three main functions:

1. creates a compressed and encrypted backup of a specified directory
1. schedules backups on a recurring basis for automated backup management using cron
1. restores backups as needed

It keeps the latest backup of a particular folder, removing older backups to conserve storage space.

**Why make this backup program?**

- I wanted a backup program that would also encrypt things and the freedom to select the encryption and compression algorithms. 
- I wanted to experiment with the best encryption and compression algorithms reasonably accessible.
- I thought it would be interesting to do this all in bash/shell, using readily available libraries (slightly works against exploring new compression algorithms).

## Installation

1. Clone this repository to your local machine.
1. Copy the `.env.example` file to `.env` and set the `ENCRYPTION_KEY` environment variable to a random string of 32 characters.
1. Save your encryption string somewhere where you won't lose it. You will need it to restore backups.
1. Install `lrzip` (on mac osx: `brew install lrzip`)
1. Run `./backup.sh` to see detailed usage notes.

The other dependencies (`zip` and `openssl` are installed by default on a mac).

## Example Usage

Reference:
`backup -d [/path/to/files] -o [/where/to/put/backup] -h [hour to repeat] [-l size limit]`

```bash
# a one time backup:
backup -d /Users/bae/Documents -o /Volumes/bae-back-that-up/

# a backup scheduled to re-occur at the 22nd hour of the day:
backup -d /Users/bae/Documents -o /Volumes/bae-back-that-up/ -h 22

# a backup that also filters out files larger than 100k
backup -d /Users/bae/Documents -o /Volumes/bae-back-that-up/ -h 22 -l 100k
```

This command will create an encrypted backup named:
`users_bae_documents.zip.lrz.enc.<8 hex>` in `/Volumes/bae-back-that-up/`.

### Parameter Details

- -d: The directory to backup (required).
- -o: The output location. The file will be named automatically (required).
- -h: An optional hour of the day (0-23) to schedule the backup to run (optional).
- -l: Limits the size of files that will be included in the backup (optional).

## Decrypting

The restore.sh script is used to decrypt and decompress a backup file.

### Example Usage

```bash
./restore.sh -f /path/to/files.zip.lrz.enc.12345678 -o /where/to/put/decrypted-backup
```

This command will take `/path/to/files.zip.lrz.enc.12345678`, decrypt it using the ENCRYPTION_KEY environment variable, and `lrzip` decompress it to `/where/to/put/decrypted-backup/files.zip`. The original encrypted file is retained in case of problems with the ENCRYPTION KEY. The zip file is left un-expanded, allowing the user to relocate it as needed.

### Parameter Details

- -f: The file to decrypt and decompress (required).
- -o: The output directory. The filename is restored with the original filename (required).

## Contributing

Contributions are welcome!

The [issues tab](https://github.com/aarons/mystic-cryptic/issues) has enhancement ideas and bugs. Please use that to raise any new issues, or to look for ideas on ways to contribute. 

For PRs, please include:
- the problem you're solving as well as a link to the issue it resolves
- an explanation of your implementation
- details of how you tested your solution
