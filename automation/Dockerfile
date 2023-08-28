# Use a lightweight base image
FROM debian:bookworm-slim

# Install required tools and MySQL client
RUN apt-get update && \
    apt-get install -y wget default-mysql-client

# Copy scripts and SQL files into the container
COPY automation/monthly_update.sh /scripts/
COPY database/import_wiki.sh /scripts/
COPY database/sql/postprocessing.sql /scripts/

# Set the working directory to /scripts
WORKDIR /scripts

# Make scripts executable
RUN chmod +x monthly_update.sh import_wiki.sh

# Install Google Cloud SDK to be able to use gcloud commands
RUN apt-get update && \
    apt-get install -y curl gnupg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && \
    apt-get update -y && apt-get install google-cloud-sdk -y

# Explicitly set entrypoint and run the monthly update script by default when the container starts
ENTRYPOINT ["/bin/bash"]
CMD ["./monthly_update.sh"]
