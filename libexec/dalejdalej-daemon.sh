#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

LIBEXEC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.dalejdalej.yaml"

SETTINGS_TMP="$(mktemp)"
trap 'rm -f "$SETTINGS_TMP"' EXIT
sed "s|__HOME__|$HOME|g" "$LIBEXEC/../claude/settings.json" > "$SETTINGS_TMP"

echo "Starting dalejdalej $(date)"

if [[ ! -f "$CONFIG" ]]; then
  echo "No config at $CONFIG, nothing to do."
  exit 0
fi

repo_count=$(yq '.repos | length' "$CONFIG")

for i in $(seq 0 $((repo_count - 1))); do
  remote=$(yq ".repos[$i].remote" "$CONFIG")
  dir=$(yq ".repos[$i].directory" "$CONFIG")
  pr_count=$(yq ".repos[$i].prs | length" "$CONFIG")

  [[ "$pr_count" -eq 0 ]] && continue

  echo "Monitoring $remote (dir: $dir)"

  for j in $(seq 0 $((pr_count - 1))); do
    pr=$(yq ".repos[$i].prs[$j]" "$CONFIG")
    echo "--- PR #$pr ---"

    status_json=$(cd "$dir" && "$LIBEXEC/pr-status.sh" "$pr")
    pr_state=$(jq -r '.state' <<<"$status_json")

    if [[ "$pr_state" != "OPEN" ]]; then
      echo "PR #$pr is $pr_state — removing from config"
      yq -i "(.repos[] | select(.remote == \"$remote\")).prs -= [$pr]" "$CONFIG"
      continue
    fi

    head_branch=$(jq -r '.headRefName' <<<"$status_json")
    base_branch=$(jq -r '.baseRefName' <<<"$status_json")

    echo "Preparing repo: $head_branch"
    git -C "$dir" fetch --quiet
    git -C "$dir" checkout -f "$head_branch" 2>/dev/null || \
      git -C "$dir" checkout --track "origin/$head_branch"
    git -C "$dir" reset --hard "origin/$head_branch"
    git -C "$dir" clean -fd --quiet
    git -C "$dir" config lfs.locksverify false 2>/dev/null || true

    behind=$(git -C "$dir" rev-list --count "HEAD..origin/$base_branch")

    summary=$(jq -r --arg behind "$behind" --arg base "$base_branch" '
      "PR #\(.number): \(.title)\n" +
      "URL: \(.url)\n" +
      "Review: \(.reviewStatus)\n" +
      "CI: \(.checksStatus)\n" +
      "Behind \($base): \($behind) commits\n" +
      "Checks:\n" +
      ( .statusCheckRollup | map("  \(.name): \(.conclusion // .status // .state)") | join("\n") )
    ' <<<"$status_json")

    (
      cd "$dir"
      gstdbuf -oL claude --verbose --output-format stream-json \
        --settings "$SETTINGS_TMP" \
        -p "Keep this PR in a mergeable state. Act on it now — do not just report.

PR status:
$summary

Available tools (use these for GitHub interaction — direct gh/curl are blocked):
  $LIBEXEC/pr-status.sh $pr          — refresh PR status JSON
  $LIBEXEC/pr-run-logs.sh <run-id>   — fetch failed-step logs for a CI run
  $LIBEXEC/pr-rerun-failed.sh $pr    — rerun all failed CI jobs

Rules:
- Behind $base_branch → checkout head branch, rebase onto origin/$base_branch, resolve conflicts, run pre-commit run -a, push --force-with-lease
- CI FAILURE → fetch logs via pr-run-logs.sh, judge: infra/flake → rerun via pr-rerun-failed.sh; real failure → fix, commit, run unit tests until everything works. push
- Nothing to fix → say so" | \
        gstdbuf -oL jq -rj --join-output '
          if .type == "assistant" then
            .message.content[] |
            if .type == "text" then .text
            elif .type == "tool_use" then ("\n[→ " + .name + " " + (.input | tostring) + "]\n")
            else empty end
          elif .type == "user" then
            .message.content[] |
            if .type == "tool_result" then
              "ToolOutput(" + (if .content then (.content | if type == "array" then map(select(.type=="text") | .text) | join("") else tostring end) else "" end | gsub("\n"; "\\n") | gsub("\r"; "")) + ")\n"
            else empty end
          else empty end
        '
    )

    echo "Done PR #$pr"
  done

  echo "Finished $remote $(date)"
done

echo "Dalejdalej finished $(date)"
