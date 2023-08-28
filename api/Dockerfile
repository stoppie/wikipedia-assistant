# Use an official Python runtime as a parent image
FROM python:3.11

# Install the Google Cloud SDK to run the `gcloud` command
RUN apt-get update && \
    apt-get install -y curl gnupg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && \
    apt-get update -y && apt-get install google-cloud-sdk -y

# Copy the requirements.txt file and install the dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container
COPY . /

# Run the application when the container launches
ENTRYPOINT ["uvicorn"]
CMD ["app.wiki_assistant:wikiapp", "--host", "0.0.0.0", "--port", "8080"]
