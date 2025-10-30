#!/bin/bash

export SERVICE_NAME=api
export ENVIRONMENT=dev
export AWS_REGION=eu-west-1
export LOG_LEVEL=INFO
export PYTHONPATH=$PWD

echo "Starting API Service..."
echo "Service: $SERVICE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Port: 8080"
echo ""
echo "Access at: http://localhost:8080"
echo "Docs at: http://localhost:8080/docs"
echo ""

../.venv/bin/uvicorn api.main:app --host 0.0.0.0 --port 8080 --reload
