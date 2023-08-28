#!/bin/bash

# Define the zone where the VM instance is located.
ZONE="us-central1-b"

# Fetch the hostname of the SQL connector VM instance from Terraform outputs.
INSTANCE_NAME=$(terraform -chdir=../terraform output --raw sql_connector_hostname)

# Copy the script to the VM instance
gcloud compute scp --zone $ZONE ./import_wiki.sh $INSTANCE_NAME:~/

# SSH into the VM instance and execute a series of commands within the instance.
gcloud compute ssh --zone $ZONE $INSTANCE_NAME --command="bash ./import_wiki.sh"