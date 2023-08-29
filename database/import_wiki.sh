#!/bin/bash

# Fetch the IP address of the SQL database instance.
export DATABASE_IP_ADDRESS=$(gcloud sql instances describe wiki-assistant-db --format 'value(ipAddresses.ipAddress)')
    
# Retrieve the root password and user password from Google Secret Manager.
export MYSQL_PWD=$(gcloud secrets versions access latest --secret='wiki-assistant-db-wiki-user-password')
    
# Define the database name and the database user.
export DATABASE_USER='wiki_user'
export DATABASE_NAME='wiki_staging'

# An array of URLs
urls=(
    "https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-page.sql.gz"
    "https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-pagelinks.sql.gz"
    "https://dumps.wikimedia.org/simplewiki/latest/simplewiki-latest-categorylinks.sql.gz"
)

MAX_RETRIES=3

# Loop over each URL and import them
for url in "${urls[@]}"; do
    filename="$(basename "$url")"
    sql_filename="${filename%.gz}"
    
    # Retry mechanism for downloads
    retry_count=0
    until [ $retry_count -ge $MAX_RETRIES ]
    do
        wget "$url" && break
        retry_count=$[$retry_count+1]
        sleep 5
    done

    if [ ! -f "$filename" ]; then
        echo "Failed to download $url after $MAX_RETRIES attempts."
        exit 1
    fi

    gunzip "$filename"
    mysql -h $DATABASE_IP_ADDRESS -u $DATABASE_USER $DATABASE_NAME < "$sql_filename"

    rm "$sql_filename"
done