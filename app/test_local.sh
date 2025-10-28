#!/bin/bash
# Local testing script for both services

echo "==================================="
echo "Kantox Services Local Testing"
echo "==================================="
echo ""

# Test if services are running
echo "1. Testing API Service (port 8080)..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "   ✓ API Service is running"
    echo ""
    echo "   Health Check:"
    curl -s http://localhost:8080/health | python3 -m json.tool
    echo ""
    echo "   Root Endpoint:"
    curl -s http://localhost:8080/ | python3 -m json.tool
else
    echo "   ✗ API Service is NOT running on port 8080"
    echo "   Start it with: cd app && ../. venv/bin/python -m uvicorn api.main:app --port 8080"
fi

echo ""
echo "==================================="
echo ""

echo "2. Testing Auxiliary Service (port 8081)..."
if curl -s http://localhost:8081/health > /dev/null 2>&1; then
    echo "   ✓ Auxiliary Service is running"
    echo ""
    echo "   Health Check:"
    curl -s http://localhost:8081/health | python3 -m json.tool
    echo ""
    echo "   Root Endpoint:"
    curl -s http://localhost:8081/ | python3 -m json.tool
else
    echo "   ✗ Auxiliary Service is NOT running on port 8081"
    echo "   Start it with: cd app && ../.venv/bin/python -m uvicorn aux.main:app --port 8081"
fi

echo ""
echo "==================================="
echo ""
echo "To start services:"
echo "  API:        cd /Users/jalbacar/code/tmp/Kantox_CE_challenge/app && SERVICE_NAME=api ENVIRONMENT=dev AWS_REGION=eu-west-1 PYTHONPATH=\$PWD ../.venv/bin/uvicorn api.main:app --host 0.0.0.0 --port 8080 --reload"
echo ""
echo "  Auxiliary:  cd /Users/jalbacar/code/tmp/Kantox_CE_challenge/app && SERVICE_NAME=aux ENVIRONMENT=dev AWS_REGION=eu-west-1 PYTHONPATH=\$PWD ../.venv/bin/uvicorn aux.main:app --host 0.0.0.0 --port 8081 --reload"
echo ""
echo "Interactive API Docs:"
echo "  API:        http://localhost:8080/docs"
echo "  Auxiliary:  http://localhost:8081/docs"
echo ""
