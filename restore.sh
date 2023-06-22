#bin/bash

# decrypt and restore journal.zip.lrz.enc
# load the passkey and IV from .env file
source .env

# see if the user wants to use the remote git message for the IV
echo "By default, this script uses the IV in .env"
echo "Would you prefer to use the IV from the last git message instead? (y/n)"
select yn in "Keep using .env variable" "Use the last git commit value instead"; do
    case $yn in
        "Keep using .env variable" )
            break;;
        "Use the last git commit value instead" )
            unset IV
            IV = $(git log -1 --oneline -- journal.zip.lrz.enc | cut -d " " -f 2-)
            break;;
    esac
done

echo "Using IV: $IV"

# decrypt the file using aes-256-cbc
openssl enc -aes-256-cbc -d -iv $IV -in journal.zip.lrz.enc -out journal.zip.lrz -pass pass:$JOURNAL_ENCRYPTION_KEY

# try to decompress the file using lrzip
lrzip -d journal.zip.lrz

# check if lrzip was successful
if [ ! -f journal.zip ]; then
    echo "journal.zip does not exist - lrzip had a failure"
    exit 1
fi

# move the zip to the documents directory
echo "Moving journal.zip to ~/Documents/journal"
mv journal.zip ~/Documents/journal

echo "removing temp journal.zip.lrz file"
rm journal.zip.lrz
