#!/bin/bash
set -e

GIT_REV=$(git log -n 1 --pretty=format:%h)

LOCAL_IMAGE=$APP_IMAGE_NAME:$GIT_REV
REMOTE_IMAGE=$IMAGE_REGISTRY/$APP_IMAGE_NAME:$GIT_REV
REMOTE_IMAGE_LATEST=$IMAGE_REGISTRY/$APP_IMAGE_NAME:latest

echo "Creating local image $LOCAL_IMAGE ..."
docker build -t $LOCAL_IMAGE .
gcloud auth configure-docker --quiet

echo "TAG/PUSH GIT HASH IMAGE $REMOTE_IMAGE ..."
docker tag $LOCAL_IMAGE $REMOTE_IMAGE
docker push $REMOTE_IMAGE

echo "TAG/PUSH LATEST $REMOTE_IMAGE_LATEST"
docker tag $LOCAL_IMAGE $REMOTE_IMAGE_LATEST
docker push $REMOTE_IMAGE_LATEST
