#!/bin/bash
set -e

# =====================================================
# BRICK 2: fileId -> CREATE FLINK JOB -> jobId
# =====================================================

# -----------------------------
# LOAD PAYLOAD FROM BOB
# -----------------------------
if [ -z "$brick2Payload" ]; then
  echo "❌ brick2Payload is not set"
  exit 1
fi

PAYLOAD="$brick2Payload"

# -----------------------------
# EXTRACT & EXPORT VARIABLES
# -----------------------------
export FILE_ID=$(echo "$PAYLOAD" | jq -r '.FILE_ID // empty')
export FILE_TYPE=$(echo "$PAYLOAD" | jq -r '.FILE_TYPE // "CSV"')

export AUTH_TOKEN=$(echo "$PAYLOAD" | jq -r '.AUTH_TOKEN // empty')
export UNIVERSE_ID=$(echo "$PAYLOAD" | jq -r '.UNIVERSE_ID // empty')
export DEST_SCHEMA_ID=$(echo "$PAYLOAD" | jq -r '.DEST_SCHEMA_ID // empty')
export SCHEMA_VERSION=$(echo "$PAYLOAD" | jq -r '.SCHEMA_VERSION // empty')

export JOB_NAME=$(echo "$PAYLOAD" | jq -r '.JOB_NAME // "kaggle-ingestion"')
export JOB_DESC=$(echo "$PAYLOAD" | jq -r '.JOB_DESC // "Auto ingestion from Kaggle"')
export JAR_VERSION=$(echo "$PAYLOAD" | jq -r '.JAR_VERSION // "15.0.4"')
export COLUMN_MAPPINGS=$(echo "$PAYLOAD" | jq -c '.COLUMN_MAPPINGS // {}')

# -----------------------------
# VALIDATION (Shell-level)
# -----------------------------
missing_vars=()

[ -z "$FILE_ID" ] && missing_vars+=("FILE_ID")
[ -z "$AUTH_TOKEN" ] && missing_vars+=("AUTH_TOKEN")
[ -z "$UNIVERSE_ID" ] && missing_vars+=("UNIVERSE_ID")
[ -z "$DEST_SCHEMA_ID" ] && missing_vars+=("DEST_SCHEMA_ID")
[ -z "$SCHEMA_VERSION" ] && missing_vars+=("SCHEMA_VERSION")

if [ ${#missing_vars[@]} -ne 0 ]; then
  echo "❌ Missing required environment variables: ${missing_vars[*]}"
  exit 1
fi

echo "✅ Environment variables loaded"
echo "   FILE_ID=$FILE_ID"
echo "   FILE_TYPE=$FILE_TYPE"
echo "   UNIVERSE_ID=$UNIVERSE_ID"
echo "   DEST_SCHEMA_ID=$DEST_SCHEMA_ID"
echo "   SCHEMA_VERSION=$SCHEMA_VERSION"

# -----------------------------
# ENSURE PYTHON
# -----------------------------
if ! command -v python3 &> /dev/null; then
  echo "❌ python3 not found"
  exit 1
fi

# =====================================================
# PYTHON EXECUTION
# =====================================================
python3 - << 'EOF'
import os
import json
import requests
import sys

FILE_ID = os.getenv("FILE_ID")
FILE_TYPE = os.getenv("FILE_TYPE", "CSV")
AUTH_TOKEN = os.getenv("AUTH_TOKEN")
UNIVERSE_ID = os.getenv("UNIVERSE_ID")
DEST_SCHEMA_ID = os.getenv("DEST_SCHEMA_ID")
SCHEMA_VERSION = os.getenv("SCHEMA_VERSION")
JOB_NAME = os.getenv("JOB_NAME")
JOB_DESC = os.getenv("JOB_DESC")
JAR_VERSION = os.getenv("JAR_VERSION")
COLUMN_MAPPINGS_STR = os.getenv("COLUMN_MAPPINGS")

COLUMN_MAPPINGS = {}
if COLUMN_MAPPINGS_STR:
    try:
        COLUMN_MAPPINGS = json.loads(COLUMN_MAPPINGS_STR)
    except Exception:
        COLUMN_MAPPINGS = {}

PI_JOB_URL = "https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v4.0/jobs"

headers = {
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Content-Type": "application/json"
}

dest_schema_full = f"{DEST_SCHEMA_ID}_{SCHEMA_VERSION}"

job_payload = {
    "universes": [UNIVERSE_ID],
    "name": JOB_NAME,
    "description": JOB_DESC,
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
    "source": {"sourceType": "FILE"},
    "tags": {"WHITE": ["KAGGLE"]}
}

print("🚀 Creating Flink job...")
print(json.dumps(job_payload, indent=2))

resp = requests.post(PI_JOB_URL, headers=headers, json=job_payload)
resp.raise_for_status()

response = resp.json()
job_id = response.get("jobId") or response.get("id")

if not job_id:
    raise RuntimeError("jobId missing in response")

print("\n==============================")
print("BRICK 2 OUTPUT (JSON)")
print(json.dumps({
    "job_id": job_id,
    "status": "CREATED",
    "job_name": JOB_NAME
}, indent=2))
print("==============================")
EOF

echo "✅ BRICK 2 COMPLETED SUCCESSFULLY"
