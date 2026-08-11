#!/usr/bin/env bash
# deploy.sh — download latest IPA from GitHub Actions and install via TrollStore SSH
# Usage: bash deploy.sh [github_repo e.g. username/arcatgame]
set -e

REPO="${1:-}"
PHONE_IP="192.168.1.168"
PHONE_USER="mobile"
PHONE_PASS="123"
IPA_NAME="ARCatGame.ipa"
REMOTE_PATH="/var/mobile/Documents/${IPA_NAME}"

# ── 1. Download IPA ──────────────────────────────────────────────────────────
if [ -n "$REPO" ]; then
  echo "⬇️  Downloading latest IPA from GitHub Actions (repo: $REPO)…"
  # Requires 'gh' CLI: https://cli.github.com
  RUN_ID=$(gh run list --repo "$REPO" --workflow build.yml --status success --limit 1 --json databaseId -q '.[0].databaseId')
  gh run download "$RUN_ID" --repo "$REPO" --name ARCatGame-ipa --dir .
  echo "✅ Downloaded ${IPA_NAME}"
else
  echo "ℹ️  No repo specified — using local ${IPA_NAME}"
  [ -f "$IPA_NAME" ] || { echo "❌ ${IPA_NAME} not found. Pass repo as first arg or place IPA here."; exit 1; }
fi

# ── 2. Copy IPA to iPhone via SCP ────────────────────────────────────────────
echo "📱 Copying IPA to iPhone at ${PHONE_IP}…"
# sshpass lets us pass password non-interactively
if ! command -v sshpass &>/dev/null; then
  echo "⚠️  sshpass not found. Install: brew install sshpass (macOS) or apt install sshpass (Linux)"
  echo "   Alternatively, set up SSH key auth: ssh-copy-id ${PHONE_USER}@${PHONE_IP}"
  exit 1
fi

sshpass -p "$PHONE_PASS" scp -o StrictHostKeyChecking=no \
  "$IPA_NAME" "${PHONE_USER}@${PHONE_IP}:${REMOTE_PATH}"

# ── 3. Install via TrollStore helper ─────────────────────────────────────────
echo "🛠️  Installing via TrollStore on iPhone…"
sshpass -p "$PHONE_PASS" ssh -o StrictHostKeyChecking=no \
  "${PHONE_USER}@${PHONE_IP}" \
  "trollstorehelper install '${REMOTE_PATH}' && rm -f '${REMOTE_PATH}'"

echo ""
echo "🎉 ARCatGame installed! Open it on your iPhone."
