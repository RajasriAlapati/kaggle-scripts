#!/bin/bash
set -e

# =====================================================
# BRICK 1: KAGGLE DOWNLOAD -> EXTRACT -> PI UPLOAD -> FILE ID
# =====================================================

echo "🔹 BRICK 1 STARTED"

# =====================================================
# STEP 0: EXTRACT VARIABLES FROM SPIN PAYLOAD
# =====================================================

if [ -z "$brick1Payload" ]; then
  echo "❌ brick1Payload is not set"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "❌ jq is required but not installed"
  exit 1
fi

export AUTH_TOKEN=$(echo "$brick1Payload" | jq -r '.AUTH_TOKEN')
export KAGGLE_DATASET=$(echo "$brick1Payload" | jq -r '.KAGGLE_DATASET')

# Fail fast
if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" = "null" ]; then
  echo "❌ AUTH_TOKEN missing in brick1Payload"
  exit 1
fi

if [ -z "$KAGGLE_DATASET" ] || [ "$KAGGLE_DATASET" = "null" ]; then
  echo "❌ KAGGLE_DATASET missing in brick1Payload"
  exit 1
fi

echo "✅ Environment variables initialized"
echo "   KAGGLE_DATASET=$KAGGLE_DATASET"
echo "   AUTH_TOKEN=***masked***"

# =====================================================
# STEP 1: ENSURE PYTHON
# =====================================================

if ! command -v python3 &> /dev/null; then
    echo "❌ python3 could not be found. Please install Python 3."
    exit 1
fi

# =====================================================
# STEP 2: RUN PYTHON LOGIC
# =====================================================

python3 - << 'EOF'
import os
import json
import zipfile
import mimetypes
import requests
import sys
import shutil
import tempfile
import subprocess
from pathlib import Path

# =====================================================
# ENV VARIABLES
# =====================================================

KAGGLE_DATASET = os.getenv("KAGGLE_DATASET")
AUTH_TOKEN = os.getenv("AUTH_TOKEN")

PI_UPLOAD_URL = "https://ig.gov-cloud.ai/pi-ingestion-service-dbaas/v2.0/jobs/upload"

missing = []
if not AUTH_TOKEN:
    missing.append("AUTH_TOKEN")
if not KAGGLE_DATASET:
    missing.append("KAGGLE_DATASET")

if missing:
    print(f"❌ Missing required environment variables: {', '.join(missing)}")
    sys.exit(1)

HEADERS = {
    "Authorization": f"Bearer {AUTH_TOKEN}"
}

# =====================================================
# WORKING DIRECTORY
# =====================================================

WORK_DIR = Path(tempfile.mkdtemp(prefix="kaggle_brick1_"))
print(f"📁 Working directory: {WORK_DIR}")

def cleanup():
    if WORK_DIR.exists():
        shutil.rmtree(WORK_DIR, ignore_errors=True)
        print("🧹 Cleanup complete")

try:
    # =====================================================
    # STEP 1: VALIDATE DATASET ACCESS
    # =====================================================

    print(f"🔍 Validating Kaggle dataset: {KAGGLE_DATASET}")
    meta_cmd = ["kaggle", "datasets", "metadata", KAGGLE_DATASET, "-p", str(WORK_DIR)]
    meta_result = subprocess.run(meta_cmd, capture_output=True, text=True)

    if meta_result.returncode != 0:
        print(meta_result.stderr)
        raise RuntimeError("Dataset not found or access denied")

    print("✅ Dataset access confirmed")

    # =====================================================
    # STEP 2: DOWNLOAD DATASET
    # =====================================================

    print("⬇️ Downloading dataset...")
    download_cmd = ["kaggle", "datasets", "download", KAGGLE_DATASET, "-p", str(WORK_DIR)]
    result = subprocess.run(download_cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError("Kaggle download failed")

    zip_files = list(WORK_DIR.glob("*.zip"))
    if not zip_files:
        raise RuntimeError("No ZIP file found after download")

    zip_file = zip_files[0]
    print(f"📦 Downloaded: {zip_file.name}")

    # =====================================================
    # STEP 3: EXTRACT & SELECT FILE
    # =====================================================

    extract_dir = WORK_DIR / "extracted"
    extract_dir.mkdir()

    with zipfile.ZipFile(zip_file, "r") as z:
        z.extractall(extract_dir)

    all_files = [f for f in extract_dir.rglob("*") if f.is_file()]
    if not all_files:
        raise RuntimeError("No files found after extraction")

    structured_exts = {".csv", ".json", ".jsonl"}
    structured = [f for f in all_files if f.suffix.lower() in structured_exts]

    target = max(structured or all_files, key=lambda f: f.stat().st_size)
    print(f"🎯 Selected file: {target.name} ({target.stat().st_size} bytes)")

    # =====================================================
    # STEP 4: UPLOAD TO PI INGESTION
    # =====================================================

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

    print(f"✅ fileId received: {file_id}")

    # =====================================================
    # OUTPUT
    # =====================================================

    output = {
        "file_id": file_id,
        "file_type": file_type,
        "original_filename": target.name
    }

    print("\n" + "=" * 60)
    print("BRICK 1 OUTPUT (JSON)")
    print(json.dumps(output, indent=2))
    print("=" * 60)

except Exception as e:
    print(f"❌ Error: {e}")
    cleanup()
    sys.exit(1)

finally:
    cleanup()
EOF

echo "✅ BRICK 1 COMPLETED SUCCESSFULLY"
