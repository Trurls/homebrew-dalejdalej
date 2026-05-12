#!/usr/bin/env bash
# Print failed-step logs for a given workflow run-id.
# Uses curl -sk + gh auth token to bypass corporate-proxy TLS issues.
set -euo pipefail
[[ $# -lt 1 ]] && { echo "Usage: pr-run-logs.sh <run-id>" >&2; exit 1; }

RUN="$1"
TOKEN=$(gh auth token)
REMOTE=$(git config --get remote.origin.url)
REPO=$(echo "$REMOTE" | sed -E 's|^.*[:/]([^/:]+/[^/]+)(\.git)?$|\1|' | sed 's/\.git$//')

api() {
  curl -sk -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"
}

JOBS=$(api "https://api.github.com/repos/$REPO/actions/runs/$RUN/jobs?per_page=100")

jq -r '.jobs[] | select(.conclusion == "failure") | "\(.id)\t\(.name)"' <<<"$JOBS" | \
while IFS=$'\t' read -r job_id job_name; do
  [[ -z "$job_id" ]] && continue
  echo "=== Job $job_id: $job_name ==="
  api -L "https://api.github.com/repos/$REPO/actions/jobs/$job_id/logs" | tail -200
  echo
done
