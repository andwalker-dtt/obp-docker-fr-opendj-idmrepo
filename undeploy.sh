#!/bin/bash
set -e

echo "Environment..."
env | grep "K8S\|GCP"

echo "Getting kubernetes creds..."
gcloud config set project $GCP_PROJECT
gcloud config set compute/zone $GCP_COMPUTE_REGION
gcloud container clusters get-credentials $GCP_K8S_CLUSTER_NAME

echo "Deleting kubectl deployment..."
kubectl delete -f $K8S_DEPLOYMENT_FILE -n $K8S_NAMESPACE

echo "Deleting kubernetes secrets..."
kubectl delete -f $K8S_SECRETS_FILE -n $K8S_NAMESPACE

echo "Delete storage volumes db-openidm-repo-0, backup-openidm-repo-0"
kubectl delete pvc db-openidm-repo-0  -n $K8S_NAMESPACE
kubectl delete pvc backup-openidm-repo-0  -n $K8S_NAMESPACE
