#!/usr/bin/env bash
# Rerun failed jobs of every failed check on a PR.
# Uses curl -sk + gh auth token to bypass corporate-proxy TLS issues.
set -euo pipefail
[[ $# -lt 1 ]] && { echo "Usage: pr-rerun-failed.sh <pr-number>" >&2; exit 1; }

PR="$1"
TOKEN=$(gh auth token)
REMOTE=$(git config --get remote.origin.url)
REPO=$(echo "$REMOTE" | sed -E 's|^.*[:/]([^/:]+/[^/]+)(\.git)?$|\1|' | sed 's/\.git$//')

api() {
  curl -sk -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"
}

HEAD_SHA=$(api "https://api.github.com/repos/$REPO/pulls/$PR" | jq -r '.head.sha')

api "https://api.github.com/repos/$REPO/commits/$HEAD_SHA/check-runs?per_page=100" \
  | jq -r '.check_runs[] | select(.conclusion == "failure") | .html_url' \
  | grep -oE 'runs/[0-9]+' | sort -u | cut -d/ -f2 \
  | while read -r run_id; do
      [[ -z "$run_id" ]] && continue
      echo "Rerunning failed jobs of run $run_id"
      api -X POST "https://api.github.com/repos/$REPO/actions/runs/$run_id/rerun-failed-jobs"
      echo
    done
