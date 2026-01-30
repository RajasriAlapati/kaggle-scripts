#!/bin/bash
set -e

echo "================ BRICK 2 START ================"

if [ -z "$BRICK2_PAYLOAD" ]; then
  echo "❌ BRICK2_PAYLOAD is not set"
  exit 1
fi

echo "✅ BRICK2_PAYLOAD received"
echo "$BRICK2_PAYLOAD"

export FILE_ID=$(echo "$BRICK2_PAYLOAD" | jq -r '.FILE_ID')
export FILE_TYPE=$(echo "$BRICK2_PAYLOAD" | jq -r '.FILE_TYPE')
export AUTH_TOKEN=$(echo "$BRICK2_PAYLOAD" | jq -r '.AUTH_TOKEN')
export UNIVERSE_ID=$(echo "$BRICK2_PAYLOAD" | jq -r '.UNIVERSE_ID')
export DEST_SCHEMA_ID=$(echo "$BRICK2_PAYLOAD" | jq -r '.DEST_SCHEMA_ID')
export SCHEMA_VERSION=$(echo "$BRICK2_PAYLOAD" | jq -r '.SCHEMA_VERSION')

# -------------------------------------------------
# 4. VALIDATION
# -------------------------------------------------
missing=()

[ -z "$FILE_ID" ] && missing+=("FILE_ID")
[ -z "$AUTH_TOKEN" ] && missing+=("AUTH_TOKEN")
[ -z "$UNIVERSE_ID" ] && missing+=("UNIVERSE_ID")
[ -z "$DEST_SCHEMA_ID" ] && missing+=("DEST_SCHEMA_ID")
[ -z "$SCHEMA_VERSION" ] && missing+=("SCHEMA_VERSION")

if [ ${#missing[@]} -ne 0 ]; then
  echo "❌ Missing required variables: ${missing[*]}"
  exit 1
fi

echo "✅ Environment validated"
echo "   FILE_ID=$FILE_ID"
echo "   FILE_TYPE=$FILE_TYPE"
echo "   UNIVERSE_ID=$UNIVERSE_ID"
echo "   DEST_SCHEMA_ID=$DEST_SCHEMA_ID"
echo "   SCHEMA_VERSION=$SCHEMA_VERSION"

# -------------------------------------------------
# 5. ENSURE PYTHON
# -------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 not found"
  exit 1
fi

# -------------------------------------------------
# 6. PYTHON – CREATE FLINK JOB
# -------------------------------------------------
python3 << 'EOF'
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
COLUMN_MAPPINGS_RAW = os.getenv("COLUMN_MAPPINGS", "{}")

# Safe JSON parse
try:
    COLUMN_MAPPINGS = json.loads(COLUMN_MAPPINGS_RAW)
    if not isinstance(COLUMN_MAPPINGS, dict):
        COLUMN_MAPPINGS = {}
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
    print("❌ jobId missing in response:")
    print(json.dumps(response, indent=2))
    sys.exit(1)

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
echo "================ BRICK 2 END ================="
