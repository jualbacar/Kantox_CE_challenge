# API Changes Summary

## Overview
Simplified the API to match exact requirements:
- **S3**: List all buckets in AWS account (not objects within buckets)
- **SSM**: Two operations only - list all parameters, get specific parameter value

## Changes Made

### 1. S3 Operations (API Service Only)

**Before:**
- `GET /storage?bucket_type=data&prefix=` - Listed objects within specific buckets
- Required S3 bucket name configuration (S3_DATA_BUCKET, S3_LOGS_BUCKET, etc.)

**After:**
- `GET /storage` - Lists all S3 buckets in the AWS account
- No bucket configuration needed

**Example:**
```bash
# Before
curl "http://localhost:8080/storage?bucket_type=data&prefix=uploads/"

# After
curl http://localhost:8080/storage
```

**Response Format:**
```json
{
  "count": 3,
  "buckets": [
    {
      "name": "kantox-data-dev",
      "creation_date": "2024-01-15T10:30:00Z"
    },
    {
      "name": "kantox-logs-dev",
      "creation_date": "2024-01-15T10:30:00Z"
    },
    {
      "name": "kantox-backups-dev",
      "creation_date": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### 2. SSM Parameter Store Operations (Both Services)

**Before:**
- `GET /config` - Get all parameters by environment path
- `GET /config/{parameter_name}` - Get parameter with path prefix construction

**After:**
- `GET /config` - List all parameters in AWS Parameter Store
- `GET /config/{parameter_name}` - Get specific parameter value (accepts full path)

**Examples:**
```bash
# List all parameters
curl http://localhost:8080/config

# Get specific parameter (using full path)
curl http://localhost:8080/config//kantox/dev/database/host

# Or get parameter by name only
curl http://localhost:8080/config/my-param
```

**Response Format for List:**
```json
{
  "count": 5,
  "parameters": [
    {
      "name": "/kantox/dev/database/host",
      "type": "String",
      "last_modified": "2024-01-15T10:30:00Z"
    },
    {
      "name": "/kantox/dev/database/port",
      "type": "String",
      "last_modified": "2024-01-15T10:30:00Z"
    }
  ]
}
```

**Response Format for Get:**
```json
{
  "name": "/kantox/dev/database/host",
  "value": "db.example.com"
}
```

### 3. Configuration Simplification

**Removed Environment Variables:**
- `S3_DATA_BUCKET`
- `S3_LOGS_BUCKET`
- `S3_BACKUPS_BUCKET`
- `SSM_PREFIX`

**Kept Environment Variables:**
- `SERVICE_NAME` (api or aux)
- `ENVIRONMENT` (dev, qa, prod)
- `AWS_REGION` (default: eu-west-1)
- `LOG_LEVEL` (default: INFO)

### 4. Code Changes

**Files Modified:**
1. `app/common/aws_client.py`:
   - S3Client: Changed `list_objects()` to `list_buckets()`
   - SSMClient: Changed `get_all_parameters()` to `list_all_parameters()`
   - SSMClient: Removed `get_parameters_by_path()` method

2. `app/common/config.py`:
   - Removed S3 bucket configuration
   - Removed SSM prefix configuration
   - Simplified to basic service settings only

3. `app/api/routers/storage.py`:
   - Simplified to single endpoint: `GET /storage`
   - Removed query parameters (bucket_type, prefix)
   - Returns list of all S3 buckets

4. `app/api/routers/config.py` and `app/aux/routers/config.py`:
   - Updated `GET /config` to list all parameters (not filtered by path)
   - Updated `GET /config/{parameter_name}` to accept full parameter paths

5. `app/api/main.py`:
   - Removed S3 bucket logging from startup

6. `app/README.md`:
   - Updated API documentation
   - Updated examples
   - Simplified environment variables section

## Testing

Both services can be tested locally:

```bash
# Start API service
cd /Users/jalbacar/code/tmp/Kantox_CE_challenge/app
./run_api.sh

# In another terminal, test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/config
curl http://localhost:8080/storage

# Start Auxiliary service
cd /Users/jalbacar/code/tmp/Kantox_CE_challenge/app
./run_aux.sh

# In another terminal, test endpoints
curl http://localhost:8081/health
curl http://localhost:8081/config
curl http://localhost:8081/storage  # Should return 404 - no S3 access
```

## IAM Permissions Required

### API Service
- **S3**: `s3:ListAllMyBuckets`
- **SSM**: `ssm:DescribeParameters`, `ssm:GetParameter`

### Auxiliary Service
- **SSM**: `ssm:DescribeParameters`, `ssm:GetParameter`
- **S3**: None (no S3 access)
