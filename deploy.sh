#!/usr/bin/env bash
# deploy.sh — download latest IPA from GitHub Actions and install via TrollStore
# Usage: bash deploy.sh [github_repo]   e.g. bash deploy.sh sosalec39/arcatgame
set -e

REPO="${1:-sosalec39/arcatgame}"
PHONE_IP="192.168.1.168"
PHONE_USER="mobile"
PHONE_PASS="123"
IPA_NAME="ARCatGame.ipa"
REMOTE_IPA="/var/mobile/Documents/${IPA_NAME}"

# SSH options that work with this device (password auth only, no pubkey)
SSH_OPTS="-T -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -o PreferredAuthentications=password"

command -v sshpass >/dev/null || { echo "❌ sshpass required. Install it first."; exit 1; }

# ── 1. Get the IPA ───────────────────────────────────────────────────────────
if [ -n "$REPO" ] && command -v gh >/dev/null; then
  echo "⬇️  Downloading latest successful build from $REPO…"
  RUN_ID=$(gh run list --repo "$REPO" --workflow build.yml --status success \
            --limit 1 --json databaseId -q '.[0].databaseId')
  rm -f "$IPA_NAME"
  gh run download "$RUN_ID" --repo "$REPO" --name ARCatGame-ipa --dir .
fi
[ -f "$IPA_NAME" ] || { echo "❌ ${IPA_NAME} not found."; exit 1; }
echo "✅ IPA ready ($(du -h "$IPA_NAME" | cut -f1))"

# ── 2. Copy to iPhone ────────────────────────────────────────────────────────
# scp is rejected by this device's sshd, so stream the file over an ssh pipe.
echo "📱 Copying to iPhone at ${PHONE_IP}…"
sshpass -p "$PHONE_PASS" ssh $SSH_OPTS "${PHONE_USER}@${PHONE_IP}" \
  "cat > ${REMOTE_IPA}" < "$IPA_NAME"

# ── 3. Install with TrollStore ───────────────────────────────────────────────
# trollstorehelper must run as root. jbctl has no rootexec, so use sudo -S.
echo "🛠️  Installing via TrollStore…"
printf '%s\n' "
TROLL=\$(find /private/var/containers/Bundle/Application -name trollstorehelper 2>/dev/null | head -1)
echo '${PHONE_PASS}' | sudo -S \"\$TROLL\" install ${REMOTE_IPA} 2>&1 | grep -E 'new app path|returning|ERROR' || true
echo '${PHONE_PASS}' | sudo -S uicache -a >/dev/null 2>&1
rm -f ${REMOTE_IPA}
" | sshpass -p "$PHONE_PASS" ssh $SSH_OPTS "${PHONE_USER}@${PHONE_IP}"

echo ""
echo "🎉 ARCatGame installed. Look for the icon on your home screen."
