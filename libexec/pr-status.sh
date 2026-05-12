#!/usr/bin/env bash
# Print PR + checks status as JSON, shaped like `gh pr view --json ...`.
# Uses curl -sk + gh auth token to bypass corporate-proxy TLS issues.
set -euo pipefail
[[ $# -lt 1 ]] && { echo "Usage: pr-status.sh <pr-number>" >&2; exit 1; }

PR="$1"
TOKEN=$(gh auth token)
REMOTE=$(git config --get remote.origin.url)
REPO=$(echo "$REMOTE" | sed -E 's|^.*[:/]([^/:]+/[^/]+)(\.git)?$|\1|' | sed 's/\.git$//')

api() {
  curl -sk -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$@"
}

PR_JSON=$(api "https://api.github.com/repos/$REPO/pulls/$PR")
HEAD_SHA=$(jq -r '.head.sha' <<<"$PR_JSON")
CHECKS_JSON=$(api "https://api.github.com/repos/$REPO/commits/$HEAD_SHA/check-runs?per_page=100")
STATUSES_JSON=$(api "https://api.github.com/repos/$REPO/commits/$HEAD_SHA/status")
REVIEWS_JSON=$(api "https://api.github.com/repos/$REPO/pulls/$PR/reviews?per_page=100")

jq -n \
  --argjson pr "$PR_JSON" \
  --argjson checks "$CHECKS_JSON" \
  --argjson statuses "$STATUSES_JSON" \
  --argjson reviews "$REVIEWS_JSON" '
def check_runs:
  $checks.check_runs // [];

def all_conclusions:
  check_runs | map(.conclusion // "") ;

def reviewStatus:
  ($reviews // [] | map(.state) ) as $states |
  if ($states | any(. == "CHANGES_REQUESTED")) then "rejected"
  elif ($states | any(. == "APPROVED")) then "accepted"
  else "pending"
  end;

def checksStatus:
  if (check_runs | length) == 0 then "no checks"
  elif (all_conclusions | all(. == "success" or . == "skipped" or . == "neutral")) then "all green"
  else "not all green"
  end;

def mergeabilityStatus:
  ($pr.mergeable_state // "unknown") as $s |
  if $s == "clean" then "mergeable"
  else "needs update (" + $s + ")"
  end;

{
  number: $pr.number,
  title: $pr.title,
  state: ($pr.state | ascii_upcase),
  merged: ($pr.merged // false),
  merged_at: ($pr.merged_at // null),
  reviewStatus: reviewStatus,
  checksStatus: checksStatus,
  mergeabilityStatus: mergeabilityStatus,
  baseRefName: $pr.base.ref,
  headRefName: $pr.head.ref,
  url: $pr.html_url,
  statusCheckRollup:
    (check_runs | map({
      __typename: "CheckRun",
      name: .name,
      status: (.status // "" | ascii_upcase),
      conclusion: (if .conclusion then (.conclusion | ascii_upcase) else null end),
      detailsUrl: .html_url,
      startedAt: .started_at,
      completedAt: .completed_at,
      workflowName: ""
    }))
    +
    ($statuses.statuses // [] | map({
      __typename: "StatusContext",
      context: .context,
      state: (.state // "" | ascii_upcase),
      targetUrl: .target_url,
      startedAt: .created_at
    }))
}
'
