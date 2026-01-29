#!/bin/bash
set -e

# =====================================================
# BRICK 2: fileId -> CREATE FLINK JOB -> jobId
# =====================================================

# Ensure python3 is available
if ! command -v python3 &> /dev/null; then
    echo " python3 could not be found. Please install Python 3."
    exit 1
fi

python3 - << 'EOF'
import os
import json
import requests
import sys

# =====================================================
# ENV VARIABLES
# =====================================================

# Input from Brick 1
FILE_ID = os.getenv("FILE_ID")
FILE_TYPE = os.getenv("FILE_TYPE", "CSV")  # CSV, JSON, or JSONL

# Required for Job Creation
AUTH_TOKEN = os.getenv("AUTH_TOKEN")
UNIVERSE_ID = os.getenv("UNIVERSE_ID")
DEST_SCHEMA_ID = os.getenv("DEST_SCHEMA_ID")
SCHEMA_VERSION = os.getenv("SCHEMA_VERSION")

# Optional
JOB_NAME = os.getenv("JOB_NAME", "kaggle-ingestion")
JOB_DESC = os.getenv("JOB_DESC", "Auto ingestion from Kaggle")
JAR_VERSION = os.getenv("JAR_VERSION", "15.0.4")
COLUMN_MAPPINGS_STR = os.getenv("COLUMN_MAPPINGS")

# Validate required
missing_vars = []
if not FILE_ID:
    missing_vars.append("FILE_ID")
if not AUTH_TOKEN:
    missing_vars.append("AUTH_TOKEN")
if not UNIVERSE_ID:
    missing_vars.append("UNIVERSE_ID")
if not DEST_SCHEMA_ID:
    missing_vars.append("DEST_SCHEMA_ID")
if not SCHEMA_VERSION:
    missing_vars.append("SCHEMA_VERSION")

if missing_vars:
    print(f" Missing required environment variables: {', '.join(missing_vars)}")
    sys.exit(1)

# Safe JSON Parse for Column Mappings
COLUMN_MAPPINGS = {}
if COLUMN_MAPPINGS_STR and COLUMN_MAPPINGS_STR.strip():
    try:
        COLUMN_MAPPINGS = json.loads(COLUMN_MAPPINGS_STR)
        if not isinstance(COLUMN_MAPPINGS, dict):
             print(" COLUMN_MAPPINGS must be a JSON object (dict), but got list. Defaulting to empty dict.")
             COLUMN_MAPPINGS = {}
    except json.JSONDecodeError:
        print(" Invalid JSON in COLUMN_MAPPINGS, defaulting to empty dict.")
        COLUMN_MAPPINGS = {}

# =====================================================
# ENDPOINTS
# =====================================================

PI_JOB_URL = "https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v4.0/jobs"

HEADERS = {
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Content-Type": "application/json"
}

# =====================================================
# MAIN LOGIC
# =====================================================

try:
    print("="*60)
    print("BRICK 2: CREATE FLINK INGESTION JOB")
    print("="*60)
    print(f" Input fileId: {FILE_ID}")
    print(f" File Type: {FILE_TYPE}")
    print(f" Universe ID: {UNIVERSE_ID}")
    
    # Build full schema name
    dest_schema_full = f"{DEST_SCHEMA_ID}_{SCHEMA_VERSION}"
    
    # =====================================================
    # CREATE FLINK JOB PAYLOAD
    # =====================================================
    
    job_payload = {
        "universes": [UNIVERSE_ID],
        "name": JOB_NAME,
        "description": JOB_DESC,
        "tags": {"WHITE": ["KAGGLE"]},
        "jobType": "ONE_TIME",
        "fileType": FILE_TYPE,
        "sinks": ["TIDB"],
        "jarVersion": JAR_VERSION,
        "mappingConfig": {
            "autoMap": True,
            "destinationSchema": dest_schema_full
        },
        "schemaConfig": {
            DEST_SCHEMA_ID: [{
                "nodeFileId": FILE_ID,
                "nodeMappings": COLUMN_MAPPINGS,
                "nodeFileType": FILE_TYPE
            }]
        },
        "source": {"sourceType": "FILE"}
    }
    
    print(f"\n Creating Flink job for schema: {dest_schema_full}")
    print(f" Job Payload:")
    print(json.dumps(job_payload, indent=2))
    
    # =====================================================
    # SUBMIT JOB API REQUEST
    # =====================================================
    
    resp = requests.post(
        PI_JOB_URL,
        headers=HEADERS,
        json=job_payload
    )
    
    resp.raise_for_status()
    
    job_response = resp.json()
    
    # Extract jobId from response
    job_id = job_response.get("jobId") or job_response.get("id")
    
    if not job_id:
        print(f" jobId not found in response. Full response:")
        print(json.dumps(job_response, indent=2))
        raise RuntimeError("jobId missing from response")
    
    print("\n Flink ingestion job created successfully!")
    
    # =====================================================
    # BRICK 2 OUTPUT
    # =====================================================
    
    output = {
        "job_id": job_id,
        "status": "CREATED",
        "job_name": JOB_NAME
    }
    
    print("\n" + "="*60)
    print("BRICK 2 OUTPUT (JSON):")
    print(json.dumps(output, indent=2))
    print("="*60)

except requests.HTTPError as e:
    print(f"\n HTTP Error: {e}")
    if e.response is not None:
        print(f"Response Status: {e.response.status_code}")
        print(f"Response Body: {e.response.text}")
    sys.exit(1)

except Exception as e:
    print(f"\n Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF
