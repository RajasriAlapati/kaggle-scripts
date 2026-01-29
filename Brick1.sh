#!/bin/bash
set -e

# =====================================================
# BRICK 1: KAGGLE DOWNLOAD -> EXTRACT -> PI UPLOAD -> FILE ID
# =====================================================

# Ensure python3 is available
if ! command -v python3 &> /dev/null; then
    echo " pthon3 could not be found. Please install Python 3."
    exit 1
fi

# Run the Python logic using heredoc
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

# Validate required
missing_vars = []
if not AUTH_TOKEN:
    missing_vars.append("AUTH_TOKEN")
if not KAGGLE_DATASET:
    missing_vars.append("KAGGLE_DATASET")

if missing_vars:
    print(f" Missing required environment variables: {', '.join(missing_vars)}")
    sys.exit(1)

HEADERS = {
    "Authorization": f"Bearer {AUTH_TOKEN}"
}

# Create a temporary directory
WORK_DIR = Path(tempfile.mkdtemp(prefix="kaggle_brick1_"))
print(f" Working directory: {WORK_DIR}")

def cleanup():
    if WORK_DIR.exists():
        shutil.rmtree(WORK_DIR, ignore_errors=True)
        print(" Cleanup complete")

try:
    # =====================================================
    # STEP 0: VALIDATE DATASET ACCESS
    # =====================================================

    print(f" Checking Kaggle dataset access: {KAGGLE_DATASET}")
    
    meta_cmd = ["kaggle", "datasets", "metadata", KAGGLE_DATASET, "-p", str(WORK_DIR)]
    meta_result = subprocess.run(meta_cmd, capture_output=True, text=True)
    
    if meta_result.returncode != 0:
        print(f" Dataset not found or access denied (Code {meta_result.returncode})")
        print(f"STDERR: {meta_result.stderr}")
        raise RuntimeError(f"Cannot access dataset {KAGGLE_DATASET}")

    print(" Dataset access confirmed")

    # =====================================================
    # STEP 1: DOWNLOAD FROM KAGGLE
    # =====================================================

    print(f" Downloading Kaggle dataset: {KAGGLE_DATASET}")
    
    cmd = ["kaggle", "datasets", "download", KAGGLE_DATASET, "-p", str(WORK_DIR)]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f" Kaggle Download Failed (Code {result.returncode})")
        print(f"STDOUT: {result.stdout}")
        print(f"STDERR: {result.stderr}")
        raise RuntimeError(f"Failed to download dataset: {result.stderr}")

    zip_files = list(WORK_DIR.glob("*.zip"))
    if not zip_files:
        raise RuntimeError("No zip file found after download")

    original_zip = zip_files[0]
    print(f" Downloaded: {original_zip.name}")

    # =====================================================
    # STEP 2: EXTRACT AND SELECT FILE
    # =====================================================
    
    print(" Extracting dataset...")
    extract_dir = WORK_DIR / "extracted"
    extract_dir.mkdir()
    
    with zipfile.ZipFile(original_zip, 'r') as zip_ref:
        zip_ref.extractall(extract_dir)
        
    # Find the largest structured file to upload
    all_files = [f for f in extract_dir.rglob("*") if f.is_file()]
    
    if not all_files:
        raise RuntimeError("No files found in extracted dataset")
        
    # Filter for likely structured data
    structured_exts = {".csv", ".json", ".jsonl"}
    structured_files = [f for f in all_files if f.suffix.lower() in structured_exts]
    
    if structured_files:
        # Pick largest structured file
        target_file = max(structured_files, key=lambda f: f.stat().st_size)
    else:
        # Fallback to largest file of any type
        target_file = max(all_files, key=lambda f: f.stat().st_size)

    print(f" Selected file for upload: {target_file.name} ({target_file.stat().st_size} bytes)")

    # =====================================================
    # STEP 3: UPLOAD TO PI INGESTION (GET fileId)
    # =====================================================

    file_type_map = {
        ".csv": "CSV",
        ".json": "JSON",
        ".jsonl": "JSONL"
    }
    
    detected_type = target_file.suffix.lower()
    file_type = file_type_map.get(detected_type, "CSV") # Default to CSV if unknown
    mime = mimetypes.guess_type(target_file)[0] or "application/octet-stream"

    print(f" Uploading to PI ingestion source as {file_type}...")

    with open(target_file, "rb") as f:
        resp = requests.post(
            PI_UPLOAD_URL,
            headers=HEADERS,
            data={"fileType": file_type},
            files={"multipartFile": (target_file.name, f, mime)}
        )

    resp.raise_for_status()
    response_json = resp.json()
    
    file_id = response_json.get("fileId")
    if not file_id and response_json.get("filesDetails"):
        try:
            file_id = response_json["filesDetails"][0].get("fileId")
        except (IndexError, AttributeError):
            pass

    if not file_id:
        print(f" Upload Response Missing fileId: {json.dumps(response_json, indent=2)}")
        raise RuntimeError("fileId not returned from PI ingestion upload")

    print(f" fileId obtained: {file_id}")

    # =====================================================
    # BRICK 1 OUTPUT
    # =====================================================
    
    output = {
        "file_id": file_id,
        "file_type": file_type,
        "original_filename": target_file.name
    }
    
    print("\n" + "="*50)
    print("BRICK 1 OUTPUT (JSON):")
    print(json.dumps(output, indent=2))
    print("="*50)

except Exception as e:
    print(f" Error: {e}")
    cleanup()
    sys.exit(1)

finally:
    cleanup()
EOF
