#!/bin/bash

# Fetch the IP address of the SQL database instance.
export DATABASE_IP_ADDRESS=$(gcloud sql instances describe wiki-assistant-db --format 'value(ipAddresses.ipAddress)')
    
# Retrieve the root password and user password from Google Secret Manager.
export MYSQL_PWD=$(gcloud secrets versions access latest --secret='wiki-assistant-db-wiki-user-password')
    
# Define the database name and the database user.
export DATABASE_USER='wiki_user'
export DATABASE_NAME='wiki_assistant'

# Step 1: Execute the import_wiki.sh script
./import_wiki.sh

# Check if the previous script executed successfully
if [ $? -ne 0 ]; then
    echo "import_wiki.sh failed. Exiting."
    exit 1
fi

# Step 2: Execute postprocessing.sql against a MySQL database

# Run the SQL script using the mysql client
mysql -h "$DATABASE_IP_ADDRESS" -u "$DATABASE_USER" "$DATABASE_NAME" < postprocessing.sql

# Check the status of the SQL execution
if [ $? -ne 0 ]; then
    echo "Execution of postprocessing.sql failed. Exiting."
    exit 1
fi

echo "Script completed successfully."
