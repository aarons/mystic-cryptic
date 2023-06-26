#!/bin/bash

echo "This script will export all 1password items to a zip file"

for item_id in $(op item list --format=json | jq --raw-output '.[].id')
do
    # avoid api limits by sleeping for 250 milliseconds between each request
    echo "Exporting item $item_id"

    item=$(op item get $item_id --format=JSON)
    if [ $? -ne 0 ]; then
        echo "Failed to get item: $item_id"
        exit 1
    fi
    item_name=$(echo $item | jq --raw-output '.title')
    # remove any spaces or weird characters from the item name
    # convert to lowercase
    clean_item_name=$(echo "$item_name" | sed 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')
    unique_name="$clean_item_name-$item_id"
    pipe_name="$unique_name.json"

    # setup a pipe with the item's name
    mkfifo $pipe_name
    echo $item > $pipe_name & zip -q --fifo -9 --display-bytes 1password_export.zip $pipe_name
    rm $pipe_name
done
