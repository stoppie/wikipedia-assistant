#!/bin/bash

# Check if a version argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION=$1
IMAGE_NAME="us-central1-docker.pkg.dev/wikipedia-assistant-397017/wiki-assistant-repo/wiki-assistant-update:$VERSION"

# Check if the image with the desired version already exists locally
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$IMAGE_NAME$"; then
  echo "Image $IMAGE_NAME already exists locally."
else
  # If the image doesn't exist locally, build it
  docker build -t $IMAGE_NAME -f Dockerfile ..
fi

# Push the image and check if the push was successful
if docker push $IMAGE_NAME; then
  # Remove the local image after a successful push
  docker rmi $IMAGE_NAME
else
  echo "Failed to push the Docker image."
  exit 1
fi
