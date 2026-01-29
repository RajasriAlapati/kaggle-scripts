#!/bin/bash
set -e

########################################
# INPUTS (Injected by Bob Workflow)
########################################

export AUTH_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICI3Ny1NUVdFRTNHZE5adGlsWU5IYmpsa2dVSkpaWUJWVmN1UmFZdHl5ejFjIn0.eyJleHAiOjE3Njk3MzE4MDYsImlhdCI6MTc2OTY5NTgwNiwianRpIjoiY2FhM2U5MDEtMzU0My00ODE4LThkYjctODU0NzI2M2FiMWI2IiwiaXNzIjoiaHR0cDovL2tleWNsb2FrLXNlcnZpY2Uua2V5Y2xvYWsuc3ZjLmNsdXN0ZXIubG9jYWw6ODA4MC9yZWFsbXMvbWFzdGVyIiwiYXVkIjpbIkJPTFRaTUFOTl9CT1RfbW9iaXVzIiwiUEFTQ0FMX0lOVEVMTElHRU5DRV9tb2JpdXMiLCJNT05FVF9tb2JpdXMiLCJWSU5DSV9tb2JpdXMiLCJhY2NvdW50Il0sInN1YiI6IjJjZjc2ZTVmLTI2YWQtNGYyYy1iY2NjLWY0YmMxZTdiZmI2NCIsInR5cCI6IkJlYXJlciIsImF6cCI6IkhPTEFDUkFDWV9tb2JpdXMiLCJzaWQiOiI4MTY3Mjc5OS1mZGVhLTQyNmItYjA1MC1iN2I5M2RlYWJhNDMiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbIi8qIl0sInJlc291cmNlX2FjY2VzcyI6eyJIT0xBQ1JBQ1lfbW9iaXVzIjp7InJvbGVzIjpbIk5FR09UQVRJT05fQVBQUk9WRSIsIk9SR0FOSVpBVElPTl9SRUFEIiwiUFJPRFVDVF9DUkVBVElPTl9SRUFEIiwiQUxMSUFOQ0VfRVhFQ1VURSIsIkFMTElBTkNFX1dSSVRFIiwiVEVOQU5UX1dSSVRFIiwiUExBVEZPUk1fV1JJVEUiLCJSQVRFX0NBUkRfV1JJVEUiLCJSQVRFX0NBUkRfQVBQUk9WRSIsIkFHRU5UU19XUklURSIsIkhPTEFDUkFDWV9VU0VSIiwiQUxMSUFOQ0VfQVBQUk9WRSIsIk5FR09UQVRJT05fV1JJVEUiLCJURU5BTlRfRVhFQ1VURSIsIlBST0RVQ1RfTElTVElOR19BUFBST1ZFIiwiUFJPRFVDVF9MSVNUSU5HX0VYRUNVVEUiLCJTVUJfQUxMSUFOQ0VfV1JJVEUiLCJQUk9EVUNUX0NSRUFUSU9OX0VYRUNVVEUiLCJORUdPVEFUSU9OX0VYRUNVVEUiLCJQUk9EVUNUX0xJU1RJTkdfV1JJVEUiLCJQUk9EVUNUX0NSRUFUSU9OX0FQUFJPVkUiLCJTVVBFUkFETUlOIiwiUFJPRFVDVF9DUkVBVElPTl9XUklURSIsIkFDQ09VTlRfUkVBRCIsIlBST0RVQ1RfTElTVElOR19SRUFEIiwiT1JHQU5JWkFUSU9OX1dSSVRFIiwiQUxMSUFOQ0VfUkVBRCIsIlJBVEVfQ0FSRF9FWEVDVVRFIiwiU1VCX0FMTElBTkNFX1JFQUQiLCJURU5BTlRfQVBQUk9WRSIsIkFHRU5UU19SRUFEIiwiREFPX0NSRUFURSIsIlBMQVRGT1JNX1JFQUQiLCJURU5BTlRfUkVBRCIsIlBMQVRGT1JNX0VYRUNVVEUiLCJTVUJfQUxMSUFOQ0VfRVhFQ1VURSIsIlNVQl9BTExJQU5DRV9BUFBST1ZFIiwiTkVHT1RBVElPTl9SRUFEIiwiQUNDT1VOVF9XUklURSIsIlBST1BPU0FMX0NSRUFURSIsIlJBVEVfQ0FSRF9SRUFEIiwiUExBVEZPUk1fQVBQUk9WRSJdfSwiQk9MVFpNQU5OX0JPVF9tb2JpdXMiOnsicm9sZXMiOlsiQk9MVFpNQU5OX0JPVF9VU0VSIiwiQk9MVFpNQU5OX0JPVF9BRE1JTiJdfSwiUEFTQ0FMX0lOVEVMTElHRU5DRV9tb2JpdXMiOnsicm9sZXMiOlsiUEFTQ0FMX0lOVEVMTElHRU5DRV9VU0VSIiwiUEFTQ0FMX0lOVEVMTElHRU5DRV9DT05TVU1FUiIsIlNDSEVNQV9XUklURSIsIlBBU0NBTF9JTlRFTExJR0VOQ0VfQURNSU4iLCJTQ0hFTUFfUkVBRCJdfSwiTU9ORVRfbW9iaXVzIjp7InJvbGVzIjpbIk1PTkVUX0FQUFJPVkUiLCJNT05FVF9VU0VSIl19LCJWSU5DSV9tb2JpdXMiOnsicm9sZXMiOlsiVklOQ0lfVVNFUiJdfSwiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJwcm9maWxlIGVtYWlsIiwicmVxdWVzdGVyVHlwZSI6IlRFTkFOVCIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiQWlkdGFhcyBBaWR0YWFzIiwidGVuYW50SWQiOiIyY2Y3NmU1Zi0yNmFkLTRmMmMtYmNjYy1mNGJjMWU3YmZiNjQiLCJwbGF0Zm9ybUlkIjoibW9iaXVzIiwicHJlZmVycmVkX3VzZXJuYW1lIjoicGFzc3dvcmRfdGVuYW50X2FpZHRhYXNAZ2FpYW5zb2x1dGlvbnMuY29tIiwiZ2l2ZW5fbmFtZSI6IkFpZHRhYXMiLCJmYW1pbHlfbmFtZSI6IkFpZHRhYXMiLCJlbWFpbCI6InBhc3N3b3JkX3RlbmFudF9haWR0YWFzQGdhaWFuc29sdXRpb25zLmNvbSIsInBsYXRmb3JtcyI6eyJyb2xlcyI6WyJTQ0hFTUFfUkVBRCJdfX0.BuxStTv-QuHqnSscLwlkAvZ9BvMEL2SAg2JWR1vbD0nGgvupx_aRWHBw7hTSJXbuGwsLZWOSzJDtDXrulHTRYNG8MF1-4SpQyGajJ2asE7wzDCkawk87DuE9j1AwwRmQN7MBHn8XDVvG0eJU6eX7L2_jM06cRoVQv_El2GaNU7jTwxSne0hG52guIKmhWPZ6juubW6iWaOgd7Fbiw_V1bCt9UqXcHziwxPufSMedNpOh4KrpmriAxSlhdB-D5mGst2xzbHqLHSynuFWs-WcvorGB-UFsLn1k0_aWW89mAc8hyb246-Wpd9lHonoB0UOP3j_aaELgrInJXYY36HR1xg"
export KAGGLE_DATASET="$KAGGLE_DATASET"
export KAGGLE_USERNAME="rajasrialapati"
export KAGGLE_KEY="1cd09c0e9ac589445d20d286c82f8083"

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
        files = resp_json.get("filesDetails", [])
        if files and isinstance(files, list):
            file_id = files[0].get("fileId")
    
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
    print(json.dumps({
    "FILE_ID": file_id,
    "FILE_TYPE": file_type
      }))
    print("=" * 60)

except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)

finally:
    cleanup()
EOF

echo "✅ BRICK 1 COMPLETED SUCCESSFULLY"
