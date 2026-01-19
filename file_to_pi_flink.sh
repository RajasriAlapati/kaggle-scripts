#!/bin/bash
set -e

########################################
# INPUTS (Injected by workflow)
########################################

INPUT_FILE="$INPUT_FILE1"
FILE_TYPE="$FILE_TYPE1"            # CSV | JSON | JSONL
UNIVERSE_ID="$UNIVERSE_ID1"
DEST_SCHEMA_ID="$DEST_SCHEMA_ID1"
SCHEMA_VERSION="$SCHEMA_VERSION1"
JOB_NAME="$JOB_NAME1"
JOB_DESC="$JOB_DESC1"
JAR_VERSION="$JAR_VERSION1"
AUTH_TOKEN="$AUTH_TOKEN1"
COLUMN_MAPPINGS="$COLUMN_MAPPINGS1"

########################################
# CONSTANTS
########################################

UPLOAD_URL="https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v2.0/jobs/upload"
JOB_URL="https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v4.0/jobs"

########################################
# VALIDATIONS (lightweight only)
########################################

if [ ! -f "$INPUT_FILE" ]; then
  echo "❌ INPUT_FILE does not exist: $INPUT_FILE"
  exit 1
fi

case "$FILE_TYPE" in
  CSV)  MIME_TYPE="text/csv" ;;
  JSON) MIME_TYPE="application/json" ;;
  JSONL) MIME_TYPE="application/json" ;;
  *)
    echo "❌ FILE_TYPE must be CSV | JSON | JSONL"
    exit 1
    ;;
esac

########################################
# STEP 1: UPLOAD FILE
########################################

echo "⬆️ Uploading file to PI ingestion service..."
echo "📄 File type: $FILE_TYPE ($MIME_TYPE)"

UPLOAD_RESPONSE=$(curl --silent --show-error --location \
  "$UPLOAD_URL" \
  --header "Authorization: Bearer ${AUTH_TOKEN}" \
  --header "Accept: application/json" \
  --form "fileType=${FILE_TYPE}" \
  --form "multipartFile=@${INPUT_FILE};type=${MIME_TYPE}")

echo "📤 Upload response:"
echo "$UPLOAD_RESPONSE"

########################################
# STEP 2: EXTRACT fileId
########################################

FILE_ID=$(echo "$UPLOAD_RESPONSE" | sed -n 's/.*"fileId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -z "$FILE_ID" ]; then
  echo "❌ Failed to extract fileId"
  exit 1
fi

echo "✅ File uploaded successfully"
echo "🆔 fileId: $FILE_ID"

########################################
# STEP 3: BUILD JOB PAYLOAD
########################################

DEST_SCHEMA_FULL="${DEST_SCHEMA_ID}_${SCHEMA_VERSION}"

JOB_PAYLOAD=$(cat <<EOF
{
  "universes": ["${UNIVERSE_ID}"],
  "name": "${JOB_NAME}",
  "description": "${JOB_DESC}",
  "jobType": "ONE_TIME",
  "fileType": "${FILE_TYPE}",
  "sinks": ["TIDB"],
  "jarVersion": "${JAR_VERSION}",
  "mappingConfig": {
    "autoMap": true,
    "destinationSchema": "${DEST_SCHEMA_FULL}"
  },
  "schemaConfig": {
    "${DEST_SCHEMA_ID}": [
      {
        "nodeFileId": "${FILE_ID}",
        "nodeMappings": ${COLUMN_MAPPINGS},
        "nodeFileType": "${FILE_TYPE}"
      }
    ]
  },
  "source": {
    "sourceType": "FILE"
  },
  "tags": {
    "BLUE": ["bob-ingestion"]
  }
}
EOF
)

########################################
# STEP 4: CREATE FLINK JOB
########################################

echo "🚀 Creating PI ingestion job..."

JOB_RESPONSE=$(curl --silent --show-error --location \
  "$JOB_URL" \
  --header "Authorization: Bearer ${AUTH_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "${JOB_PAYLOAD}")

echo "🎯 Job creation response:"
echo "$JOB_RESPONSE"

echo "✅ INGESTION PIPELINE TRIGGERED SUCCESSFULLY"
