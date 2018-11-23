#!/bin/bash
set -e

echo "Environment..."
env | grep "K8S\|GCP"

GIT_REV=$(git log -n 1 --pretty=format:%h)
IMG_TAG_TO_DEPLOY=$IMAGE_REGISTRY/$APP_IMAGE_NAME:$GIT_REV

echo "$IMG_TAG_TO_DEPLOY will be deployed..."

echo "Getting kubernetes creds..."
gcloud config set project $GCP_PROJECT
gcloud config set compute/zone $GCP_COMPUTE_REGION
gcloud container clusters get-credentials $GCP_K8S_CLUSTER_NAME

echo "Creating kubernetes secrets..."
kubectl apply -f $K8S_SECRETS_FILE -n $K8S_NAMESPACE

echo "Executing kubectl deployment..."
kubectl apply -f $K8S_DEPLOYMENT_FILE -n $K8S_NAMESPACE

image=${IMG_TAG_TO_DEPLOY}
patch_json="[{\"op\": \"replace\",\"path\": \"/spec/template/spec/containers/0/image\",\"value\": \"${image}\"},{\"op\": \"replace\",\"path\": \"/spec/template/spec/initContainers/0/image\",\"value\": \"${image}\"}]"
echo "kubectl patch statefulset ${K8S_DEPLOYMENT_NAME} -p "${patch_json}" --type 'json' -n ${K8S_NAMESPACE}"
kubectl patch statefulset ${K8S_DEPLOYMENT_NAME} -p "${patch_json}" --type 'json' -n ${K8S_NAMESPACE}

echo "Wait for deployment to finish..."
kubectl rollout status sts/$K8S_DEPLOYMENT_NAME -n $K8S_NAMESPACE
