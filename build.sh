#!/bin/bash

set -e  #Any error will stop the script immediately (optional).

# ========================
# Variables
# ========================
cluster_name="cluster-1-dev"
region="us-east-1"
aws_id="460840353653"
repo_name="goapp-survey"
image_name="$aws_id.dkr.ecr.$region.amazonaws.com/$repo_name:latest"
domain="disslite.com"
namespace="go-survey"

# ========================
# Update Helm Repos
# helm repo update
# ========================
# echo "--------------------Updating Helm Repos--------------------"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add autoscaler https://kubernetes.github.io/autoscaler || true
helm repo update

# ========================
# build the infrastructure
echo "--------------------Creating EKS--------------------"
echo "--------------------Creating ECR--------------------"
echo "--------------------Creating EBS--------------------"
echo "--------------------Deploying Ingress--------------------"
echo "--------------------Deploying Monitoring--------------------"
cd terraform && \
terraform init && \
terraform apply -auto-approve && \
cd ..

# update kubeconfig
echo "--------------------Update Kubeconfig--------------------"
aws eks update-kubeconfig --name $cluster_name --region $region

# remove preious docker images
echo "--------------------Remove Previous build--------------------"
docker rmi -f $image_name || true

# build new docker image with new tag
echo "--------------------Build new Image--------------------"
docker build -t $image_name ./Go-app/

#ECR Login
echo "--------------------Login to ECR--------------------"
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $aws_id.dkr.ecr.$region.amazonaws.com

# push the latest build to dockerhub
echo "--------------------Pushing Docker Image--------------------"
docker push $image_name

# create namespace
echo "--------------------creating Namespace--------------------"
kubectl create ns $namespace || true

# deploy app
echo "--------------------Deploy App--------------------"
kubectl apply -n $namespace -f k8s

# Wait for application to be deployed
echo "--------------------Wait for all pods to be running--------------------"
sleep 60s

# Get ingress URL
echo "--------------------Ingress URL--------------------"
kubectl get ingress go-app-ingress -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo " "
echo " "
echo "--------------------Application URL--------------------"
echo "http://goapp.$domain"

echo "--------------------Alertmanager URL--------------------"
echo "http://alertmanager.$domain"
echo " "

echo "--------------------Prometheus URL--------------------"
echo "http://prometheus.$domain"
echo " "

echo "--------------------Grafana URL--------------------"
echo "http://grafana.$domain"
echo " "
echo " "

echo -e "1. Navigate to your domain cpanel.\n2. Look for Zone Editor.\n3. Add CNAME Record to your domain.\n4. In the name type domain for your application.\n5. In the CNAME Record paste the ingress URL."