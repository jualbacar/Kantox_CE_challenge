#!/bin/bash

#
# refresh-ecr-credentials.sh
#
# Refreshes ECR registry secrets in Kubernetes namespaces
# ECR authentication tokens expire after 12 hours, requiring periodic refresh
#
# NOTE: This script is intended for local Minikube development.
# For production EKS deployments, use IAM Roles for Service Accounts (IRSA) instead:
# https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
NAMESPACES=("api" "aux")

echo ""
echo "🔑 ECR Credentials Refresh Script"
echo "=================================="
echo ""

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Error: Cannot connect to Kubernetes cluster${NC}"
    echo "   Make sure Minikube is running: minikube status"
    exit 1
fi

# Get AWS account ID
echo "📋 Getting AWS account information..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Error: Cannot get AWS account ID. Check your AWS credentials${NC}"
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo -e "${GREEN}✓${NC} AWS Account: ${AWS_ACCOUNT_ID}"
echo -e "${GREEN}✓${NC} ECR Registry: ${ECR_REGISTRY}"
echo ""

# Get fresh ECR token
echo "🔐 Obtaining fresh ECR authentication token..."
ECR_PASSWORD=$(aws ecr get-login-password --region "$AWS_REGION" 2>/dev/null)
if [ -z "$ECR_PASSWORD" ]; then
    echo -e "${RED}❌ Error: Failed to get ECR token${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} ECR token obtained"
echo ""

# Update secrets in each namespace
for NAMESPACE in "${NAMESPACES[@]}"; do
    echo "🔄 Updating ECR secret in namespace: ${NAMESPACE}"
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo -e "${YELLOW}⚠${NC}  Namespace ${NAMESPACE} does not exist, skipping..."
        continue
    fi
    
    # Delete existing secret (ignore if not found)
    kubectl delete secret ecr-registry-secret -n "$NAMESPACE" --ignore-not-found > /dev/null 2>&1
    
    # Create new secret
    if kubectl create secret docker-registry ecr-registry-secret \
        --docker-server="$ECR_REGISTRY" \
        --docker-username=AWS \
        --docker-password="$ECR_PASSWORD" \
        --namespace="$NAMESPACE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Secret updated in ${NAMESPACE} namespace"
    else
        echo -e "${RED}❌ Failed to update secret in ${NAMESPACE} namespace${NC}"
    fi
done

echo ""
echo "🔄 Restarting deployments to pick up new secrets..."
echo ""

# Restart deployments
for NAMESPACE in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        DEPLOYMENT_NAME="$NAMESPACE"
        if kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" &> /dev/null; then
            kubectl rollout restart deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" > /dev/null 2>&1
            echo -e "${GREEN}✓${NC} Restarted ${DEPLOYMENT_NAME} deployment in ${NAMESPACE} namespace"
        fi
    fi
done

echo ""
echo "✅ ECR credentials refresh complete!"
echo ""
echo "💡 Tip: ECR tokens expire every 12 hours. Run this script whenever you see ImagePullBackOff errors."
echo ""
echo "📊 Check pod status with:"
echo "   kubectl get pods -n api"
echo "   kubectl get pods -n aux"
echo ""
