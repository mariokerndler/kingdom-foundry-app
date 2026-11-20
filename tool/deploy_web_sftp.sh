#!/usr/bin/env bash
set -euo pipefail

: "${HOSTINGER_SFTP_HOST:?Set HOSTINGER_SFTP_HOST}"
: "${HOSTINGER_SFTP_USERNAME:?Set HOSTINGER_SFTP_USERNAME}"
: "${HOSTINGER_SSH_PRIVATE_KEY:?Set HOSTINGER_SSH_PRIVATE_KEY}"
: "${HOSTINGER_SSH_KNOWN_HOSTS:?Set HOSTINGER_SSH_KNOWN_HOSTS}"
: "${HOSTINGER_SERVER_DIR:?Set HOSTINGER_SERVER_DIR}"
port="${HOSTINGER_SFTP_PORT:-65002}"

# Restrict batch-command input so configuration cannot introduce SFTP commands.
if [[ ! "$HOSTINGER_SERVER_DIR" =~ ^[a-zA-Z0-9_./-]+/$ ||
      ! "$HOSTINGER_SFTP_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ||
      ! "$HOSTINGER_SFTP_USERNAME" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ||
      ! "$port" =~ ^[0-9]{1,5}$ ]] || (( 10#$port < 1 || 10#$port > 65535 )); then
  echo 'Invalid SFTP host, username, port or destination (use a path ending in /).' >&2
  exit 1
fi
test -f build/web/index.html
test -f build/web/pwa_service_worker.js

umask 077
credentials=$(mktemp -d)
trap 'rm -f "$credentials/key" "$credentials/known_hosts"; rmdir "$credentials"' EXIT
printf '%s\n' "$HOSTINGER_SSH_PRIVATE_KEY" > "$credentials/key"
printf '%s\n' "$HOSTINGER_SSH_KNOWN_HOSTS" > "$credentials/known_hosts"

# shortcut: old remote assets remain; add a deployment manifest if cleanup is needed.
printf 'cd "%s"\nput -R build/web/*\n' "$HOSTINGER_SERVER_DIR" |
  sftp -b - -P "$port" -i "$credentials/key" \
    -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$credentials/known_hosts" \
    -o ConnectTimeout=30 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
    "$HOSTINGER_SFTP_USERNAME@$HOSTINGER_SFTP_HOST"
