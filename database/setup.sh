#!/bin/bash

# Define the zone where the VM instance is located.
ZONE="us-central1-b"

# Fetch the hostname of the SQL connector VM instance from Terraform outputs.
INSTANCE_NAME=$(terraform -chdir=terraform output --raw sql_connector_hostname)

# Securely copy setup files to the VM instance.
gcloud compute scp --zone $ZONE database/python/setup.py $INSTANCE_NAME:~/

# SSH into the VM instance and execute a series of commands within the instance.
gcloud compute ssh --zone $ZONE $INSTANCE_NAME --command="
    # Fetch the IP address of the SQL database instance.
    export DATABASE_IP_ADDRESS=\$(gcloud sql instances describe wiki-assistant-db --format 'value(ipAddresses.ipAddress)')
    
    # Retrieve the passwords from Google Secret Manager.
    export MYSQL_PWD=\$(gcloud secrets versions access latest --secret='wiki-assistant-db-root-password')
    export DATABASE_DEV_USER_PWD=\$(gcloud secrets versions access latest --secret='wiki-assistant-db-wiki-user-password')
    export DATABASE_API_USER_PWD=\$(gcloud secrets versions access latest --secret='wiki-assistant-db-api-user-password')

    # Define the database names.
    export DATABASE_PROD_NAME='wiki_assistant'
    export DATABASE_STAGING_NAME='wiki_staging'

    # Define the database users
    export DATABASE_DEV_USER='wiki_user'
    export DATABASE_API_USER='api_user'

    # Create a new Python virtual environment.
    python3 -m venv development

    # Activate the virtual environment.
    source development/bin/activate

    # Install the MySQL connector package within the virtual environment.
    pip install mysql-connector-python

    # Execute the Python script to set up the MySQL database using the retrieved and defined parameters.
    python3 setup.py \$DATABASE_IP_ADDRESS \$MYSQL_PWD \$DATABASE_PROD_NAME \$DATABASE_STAGING_NAME \$DATABASE_DEV_USER \$DATABASE_DEV_USER_PWD \$DATABASE_API_USER \$DATABASE_API_USER_PWD
"
