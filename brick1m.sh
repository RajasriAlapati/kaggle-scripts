#!/bin/bash
set -e

########################################
# INPUTS (Injected by Bob Workflow)
########################################

export AUTH_TOKEN="$AUTH_TOKEN"
export KAGGLE_DATASET="$KAGGLE_DATASET"
export KAGGLE_USERNAME="$KAGGLE_USERNAME"
export KAGGLE_KEY="$KAGGLE_KEY"

########################################
# CONSTANTS
########################################

PI_UPLOAD_URL="https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v2.0/jobs/upload"

########################################
# VALIDATIONS
########################################

echo "🔧 Installing kaggle CLI at runtime..."

python3 -m pip install --user --quiet kaggle

# IMPORTANT: Bob runs as cloud-user
export PATH="/home/cloud-user/.local/bin:$PATH"

# Debug (remove later)
echo "🔍 kaggle location check"
ls -l /home/cloud-user/.local/bin || true
echo "🔍 PATH=$PATH"

if ! command -v kaggle &> /dev/null; then
  echo "❌ kaggle CLI not found even after PATH fix"
  exit 1
fi

echo "✅ kaggle CLI is available"

########################################
# CONFIGURE KAGGLE AUTH
########################################

if [ -z "$KAGGLE_USERNAME" ] || [ -z "$KAGGLE_KEY" ]; then
  echo "❌ KAGGLE_USERNAME or KAGGLE_KEY is missing"
  exit 1
fi

mkdir -p /home/cloud-user/.config/kaggle

cat > /home/cloud-user/.config/kaggle/kaggle.json <<EOF
{
  "username": "${KAGGLE_USERNAME}",
  "key": "${KAGGLE_KEY}"
}
EOF

chmod 600 /home/cloud-user/.config/kaggle/kaggle.json

echo "✅ kaggle.json configured"



if [ -z "$AUTH_TOKEN" ]; then
  echo " AUTH_TOKEN is missing"
  exit 1
fi

if [ -z "$KAGGLE_DATASET" ]; then
  echo " KAGGLE_DATASET is missing"
  exit 1
fi

if ! command -v python3 &> /dev/null; then
  echo "❌ python3 not found"
  exit 1
fi

if ! command -v kaggle &> /dev/null; then
  echo "❌ kaggle CLI not found"
  exit 1
fi

echo "✅ Inputs validated"
echo "   KAGGLE_DATASET=$KAGGLE_DATASET"
echo "   AUTH_TOKEN=***masked***"

########################################
# EXECUTION (PYTHON)
########################################

python3 - << 'EOF'
import os
import json
import zipfile
import mimetypes
import requests
import tempfile
import shutil
import subprocess
import sys
from pathlib import Path

AUTH_TOKEN = os.getenv("AUTH_TOKEN")
KAGGLE_DATASET = os.getenv("KAGGLE_DATASET")
PI_UPLOAD_URL = "https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v2.0/jobs/upload"

HEADERS = {
    "Authorization": f"Bearer {AUTH_TOKEN}"
}

work_dir = Path(tempfile.mkdtemp(prefix="kaggle_brick1_"))
print(f"📁 Working directory: {work_dir}")

def cleanup():
    shutil.rmtree(work_dir, ignore_errors=True)
    print("🧹 Cleanup complete")

try:
    # ---------------------------------
    # STEP 1: Validate dataset
    # ---------------------------------
    print(f"🔍 Validating Kaggle dataset: {KAGGLE_DATASET}")
    result = subprocess.run(
        ["kaggle", "datasets", "metadata", KAGGLE_DATASET, "-p", str(work_dir)],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)

    print("✅ Dataset access confirmed")

    # ---------------------------------
    # STEP 2: Download dataset
    # ---------------------------------
    print("⬇️ Downloading dataset")
    result = subprocess.run(
        ["kaggle", "datasets", "download", KAGGLE_DATASET, "-p", str(work_dir)],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)

    zip_files = list(work_dir.glob("*.zip"))
    if not zip_files:
        raise RuntimeError("No zip file downloaded")

    zip_file = zip_files[0]
    print(f"📦 Downloaded: {zip_file.name}")

    # ---------------------------------
    # STEP 3: Extract & choose file
    # ---------------------------------
    extract_dir = work_dir / "extracted"
    extract_dir.mkdir()

    with zipfile.ZipFile(zip_file, "r") as z:
        z.extractall(extract_dir)

    all_files = [f for f in extract_dir.rglob("*") if f.is_file()]
    if not all_files:
        raise RuntimeError("No files after extraction")

    structured_exts = {".csv", ".json", ".jsonl"}
    structured = [f for f in all_files if f.suffix.lower() in structured_exts]

    target = max(structured or all_files, key=lambda f: f.stat().st_size)
    print(f"🎯 Selected file: {target.name}")

    # ---------------------------------
    # STEP 4: Upload to PI ingestion
    # ---------------------------------
    file_type_map = {
        ".csv": "CSV",
        ".json": "JSON",
        ".jsonl": "JSONL"
    }

    file_type = file_type_map.get(target.suffix.lower(), "CSV")
    mime = mimetypes.guess_type(target)[0] or "application/octet-stream"

    print(f"⬆️ Uploading file as {file_type}")

    with open(target, "rb") as f:
        resp = requests.post(
            PI_UPLOAD_URL,
            headers=HEADERS,
            data={"fileType": file_type},
            files={"multipartFile": (target.name, f, mime)}
        )

    resp.raise_for_status()
    resp_json = resp.json()

    file_id = resp_json.get("fileId")
    if not file_id:
        raise RuntimeError(f"fileId missing in response: {resp_json}")

    # ---------------------------------
    # OUTPUT (Bob reads logs)
    # ---------------------------------
    output = {
        "file_id": file_id,
        "file_type": file_type,
        "filename": target.name
    }

    print("\n" + "=" * 60)
    print("BRICK 1 OUTPUT (JSON)")
    print(json.dumps(output, indent=2))
    print("=" * 60)

except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)

finally:
    cleanup()
EOF

echo "✅ BRICK 1 COMPLETED SUCCESSFULLY"
