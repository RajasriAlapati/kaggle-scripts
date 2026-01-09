#!/bin/bash

set -e  # Fail fast, fail loud

########################################
# INPUTS (FROM USER / BOB WORKFLOW)
########################################

KAGGLE_DATASET="${KAGGLE_DATASET}"      # e.g. arshid/iris-flower-dataset
AUTH_TOKEN="${AUTH_TOKEN}"              # Injected secret

FILE_PATH="${FILE_PATH:-kaggle}"        # Optional
CONTENT_TAGS="${CONTENT_TAGS:-kaggle,pi-schema}"

########################################
# CONSTANTS
########################################

WORK_DIR="/tmp/kaggle_ingestion"
ZIP_FILE="dataset.zip"

CONTENT_SERVICE_URL="https://ig.gov-cloud.ai/mobius-content-service/v1.0/content/upload"

########################################
# VALIDATIONS
########################################

echo "🔎 Validating inputs..."

if [ -z "$KAGGLE_DATASET" ]; then
  echo "❌ KAGGLE_DATASET is required (username/dataset-name)"
  exit 1
fi

if [ -z "$AUTH_TOKEN" ]; then
  echo "❌ AUTH_TOKEN is required"
  exit 1
fi

command -v kaggle >/dev/null 2>&1 || {
  echo "❌ Kaggle CLI not available in runtime"
  exit 1
}

########################################
# STEP 1: VALIDATE DATASET ACCESS
########################################

echo "🔐 Checking Kaggle dataset access: $KAGGLE_DATASET"

if ! kaggle datasets metadata "$KAGGLE_DATASET" > /dev/null 2>&1; then
  echo "❌ Dataset not found or access denied"
  exit 1
fi

echo "✅ Dataset access confirmed"

########################################
# STEP 2: DOWNLOAD DATASET
########################################

echo "📥 Downloading dataset..."

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

kaggle datasets download "$KAGGLE_DATASET"

########################################
# STEP 3: EXTRACT DATASET
########################################

echo "📦 Extracting dataset files"
unzip -o "*.zip"

########################################
# STEP 4: PACKAGE FOR CDN UPLOAD
########################################

echo "🗜️ Packaging dataset for upload"
zip -r "$ZIP_FILE" . -x "*.zip"

########################################
# STEP 5: UPLOAD TO CONTENT SERVICE
########################################

echo "☁️ Uploading to Mobius Content Service"

RESPONSE=$(curl --silent --show-error --location \
  "${CONTENT_SERVICE_URL}?filePath=${FILE_PATH}&contentTags=${CONTENT_TAGS}" \
  --header "Authorization: Bearer ${AUTH_TOKEN}" \
  --form "file=@${ZIP_FILE}")

########################################
# STEP 6: OUTPUT FOR NEXT BRICK
########################################

echo "🎯 Upload completed successfully"
echo "📤 Content Service Response:"
echo "$RESPONSE"
