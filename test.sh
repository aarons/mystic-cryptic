#bin/bash

# this is used to validate working with openssl encryption
# you can safely ignore it unless you want to try it too

# load the passkey variable from .env file
source .env

# then encrypt the file using aes-256-cbc no IV
openssl enc -aes-256-cbc -in backup.sh -out backup.enc -pass pass:$JOURNAL_ENCRYPTION_KEY
openssl enc -d -aes-256-cbc -in backup.enc -out decrypted-backup.sh -pass pass:$JOURNAL_ENCRYPTION_KEY

# test with IV
# get a random hex string for IV
IV=$(head -c 8 /dev/urandom | xxd -p)

# update the IV variable with the latest iv value in the existing .env file
sed -i '' "s/IV=.*/IV=$IV/" .env

# encrypt backup.sh
openssl enc -aes-256-cbc -iv $IV -in backup.sh -out backup-iv.enc -pass pass:$JOURNAL_ENCRYPTION_KEY

# clear the IV variable from current session to test .env file writing and reading
unset IV
source .env

# decrypt the file
openssl enc -d -aes-256-cbc -iv $IV -in backup-iv.enc -out decrypted-iv-backup.sh -pass pass:$JOURNAL_ENCRYPTION_KEY
