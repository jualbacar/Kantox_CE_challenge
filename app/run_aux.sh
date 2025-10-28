#!/bin/bash
# Script to run the Auxiliary service locally

export SERVICE_NAME=aux
export ENVIRONMENT=dev
export AWS_REGION=eu-west-1
export LOG_LEVEL=INFO
export PYTHONPATH=$PWD

echo "Starting Auxiliary Service..."
echo "Service: $SERVICE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Port: 8081"
echo ""
echo "Access at: http://localhost:8081"
echo "Docs at: http://localhost:8081/docs"
echo ""

../.venv/bin/uvicorn aux.main:app --host 0.0.0.0 --port 8081 --reload
