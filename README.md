# Backup and Encrypt Script

**This project is in development; while it works, there are some issues with the scheduling module.**

This script provides three main functions:

1. creating a compressed and encrypted backup of a specified directory
1. scheduling backups on a recurring basis for automated backup management
1. restoring backups as needed

Currently it preserves only the latest backup of a particular folder, removing older ones to conserve storage space.

## Installation

1. Clone this repository to your local machine.
1. Copy the `.env.example` file to `.env` and set the `ENCRYPTION_KEY` environment variable to a random string of 32 characters.
1. Save your encryption string somewhere where you won't lose it. You will need it to restore backups.
1. Install `lrzip` (on mac osx: `brew install lrzip`)
1. Run `./backup.sh` to see detailed usage notes.

The other dependencies (`zip` and `openssl` are installed by default on a mac).

## Usage

```bash
backup -d /path/to/files -o /where/to/put/backup [-h HOUR]
backup -d /Users/bae/Documents -o /Volumes/bae-back-that-up/ -h 22
```

This command will create an encrypted backup named:
`users_bae_documents.zip.lrz.enc.<8 hex>` in `/Volumes/bae-back-that-up/`.

### Parameters

- -d: The directory to backup.
- -o: The output location. The file will be named automatically.
- -h: An optional hour of the day (0-23) to schedule the backup to run (optional).


## Decrypting

The restore.sh script is used to decrypt and decompress a backup file.

Usage:

```bash
./restore.sh -f /path/to/files.zip.lrz.enc.12345678 -o /where/to/put/decrypted-backup
```

### Parameters:

- -f: The file to decrypt and decompress (required).
- -o: The output directory. The filename is restored with the original filename (required).

This command will take `/path/to/files.zip.lrz.enc.12345678`, decrypt it using the ENCRYPTION_KEY environment variable, and decompress it to `/where/to/put/backup/files.zip`. The original encrypted file is retained in case of problems with the ENCRYPTION KEY.
