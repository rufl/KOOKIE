#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${GITHUB_REPOSITORY:-rufl/KOOKIE}"
ENVIRONMENT="kookie-demo-release"
SIGNING_KEY="${KOOKIE_SIGNING_KEY:-}"
KOF_ARCHIVE="${KOOKIE_KOF_ARCHIVE:-}"
VERSION=""
APPLY=0
QUALIFY=0
PUBLISH=0
LINUX_SMOKE=false
WINDOWS_SMOKE=false
REVIEWERS=()
HARDWARE_EVIDENCE=0


usage() {
  cat <<'EOF'
Usage: scripts/bootstrap_release.sh [options]

Validates local release inputs, optionally configures the GitHub secrets and
approval environment, then optionally runs qualification and publication. It
never creates signing keys, prints key contents, replaces self-hosted runners,
or bypasses environment approval.

Required for every run:
  --signing-key PATH       permanent owner-controlled Ed25519 key, mode 0600
  --kof-archive PATH       exact Kof 0.5.0-beta distribution archive

Remote configuration:
  --apply                  update GitHub secrets and the approval environment
  --reviewer LOGIN         required-reviewer GitHub login; repeat as needed

Workflow execution:
  --qualify                dispatch and watch publish=false qualification
  --publish                after qualification, dispatch publish=true
  --confirm-hardware-evidence
  --version VERSION        release version, required with --qualify/--publish
  --linux-presentation-smoke
  --windows-wine-smoke

Other:
  --repo OWNER/REPO        GitHub repository (default: rufl/KOOKIE)
  --help                   show this help

Examples:
  # Validate only; no GitHub mutation
  scripts/bootstrap_release.sh \
    --signing-key "$HOME/.config/kookie/release/kookie-ed25519.pem" \
    --kof-archive /path/to/kof-0.5.0-beta-linux-x86_64.tar.gz

  # Configure secrets/environment and qualify
  scripts/bootstrap_release.sh --apply \
    --reviewer release-admin \
    --signing-key "$HOME/.config/kookie/release/kookie-ed25519.pem" \
    --kof-archive /path/to/kof-0.5.0-beta-linux-x86_64.tar.gz \
    --version 0.1.0-dogfood.37 --qualify

  # Configure, qualify, then publish only after qualification succeeds
  scripts/bootstrap_release.sh --apply \
    --reviewer release-admin \
    --signing-key "$HOME/.config/kookie/release/kookie-ed25519.pem" \
    --kof-archive /path/to/kof-0.5.0-beta-linux-x86_64.tar.gz \
    --version 0.1.0-dogfood.37 --qualify --publish \
    --confirm-hardware-evidence
EOF
}

fail() {
  printf 'bootstrap_release: %s\n' "$1" >&2
  exit 2
}
require_value() {
  [[ $# -eq 2 && -n "$2" ]] ||
    fail "$1 requires a non-empty value"
}


while (($#)); do
  case "$1" in
    --repo) require_value "$1" "${2-}"; REPO="$2"; shift 2 ;;
    --signing-key) require_value "$1" "${2-}"; SIGNING_KEY="$2"; shift 2 ;;
    --kof-archive) require_value "$1" "${2-}"; KOF_ARCHIVE="$2"; shift 2 ;;
    --reviewer) require_value "$1" "${2-}"; REVIEWERS+=("$2"); shift 2 ;;
    --version) require_value "$1" "${2-}"; VERSION="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --qualify) QUALIFY=1; shift ;;
    --publish) PUBLISH=1; shift ;;
    --confirm-hardware-evidence) HARDWARE_EVIDENCE=1; shift ;;
    --linux-presentation-smoke) LINUX_SMOKE=true; shift ;;
    --windows-wine-smoke) WINDOWS_SMOKE=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

if (( PUBLISH == 1 && QUALIFY == 0 )); then
  fail '--publish requires --qualify in the same invocation'
fi
if (( PUBLISH == 1 && APPLY == 0 )); then
  fail '--publish requires --apply as an explicit safety acknowledgement'
fi
if (( QUALIFY == 1 || PUBLISH == 1 )); then
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
    fail '--version must be SemVer without a leading v'
fi
if (( PUBLISH == 1 && HARDWARE_EVIDENCE == 0 )); then
  fail '--publish requires --confirm-hardware-evidence'
fi
if (( APPLY == 1 && ${#REVIEWERS[@]} == 0 )); then
  fail '--apply requires at least one --reviewer LOGIN'
fi

for command_name in bash cut grep openssl sha256sum stat; do
  command -v "$command_name" >/dev/null || fail "$command_name is required"
done
[[ -x "$ROOT_DIR/scripts/check_release_readiness.sh" ]] ||
  fail 'scripts/check_release_readiness.sh is missing or not executable'

printf 'Repository: %s\nEnvironment: %s\n' "$REPO" "$ENVIRONMENT"

local_check=0
set +e
bash "$ROOT_DIR/scripts/check_release_readiness.sh" \
  --skip-github \
  --signing-key "$SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
local_check=$?
set -e
(( local_check == 0 )) || exit "$local_check"

kof_sha256="$(sha256sum "$KOF_ARCHIVE" | cut -d ' ' -f 1)"

if (( APPLY == 0 )); then
  printf 'Plan only: no GitHub secrets or environment changes will be made.\n'
else
  command -v gh >/dev/null || fail 'gh is required with --apply'
  command -v jq >/dev/null || fail 'jq is required with --apply'
  gh auth status --hostname github.com >/dev/null 2>&1 ||
    fail 'gh is not authenticated for github.com'

  reviewer_json='[]'
  for reviewer in "${REVIEWERS[@]}"; do
    [[ "$reviewer" =~ ^[A-Za-z0-9-]+$ ]] ||
      fail "reviewer must be a GitHub user login: $reviewer"
    reviewer_id="$(gh api "users/$reviewer" --jq '.id')" ||
      fail "cannot resolve GitHub reviewer: $reviewer"
    reviewer_json="$(jq -cn --argjson current "$reviewer_json" \
      --argjson reviewer_id "$reviewer_id" \
      '$current + [{type: "User", id: $reviewer_id}]')"
  done

  environment_payload="$(jq -cn --argjson reviewers "$reviewer_json" \
    '{wait_timer: 0, prevent_self_review: true, reviewers: $reviewers,
      deployment_branch_policy: {protected_branches: false,
      custom_branch_policies: false}}')"
  printf '%s' "$environment_payload" |
    gh api --method PUT "repos/$REPO/environments/$ENVIRONMENT" --input - >/dev/null
  printf 'Environment configured with %s required reviewer(s).\n' \
    "${#REVIEWERS[@]}"

  gh secret set KOOKIE_SIGNING_KEY_PEM --repo "$REPO" < "$SIGNING_KEY"
  gh secret set KOOKIE_KOF_ARCHIVE_SHA256 --repo "$REPO" --body "$kof_sha256"
  printf 'GitHub secrets configured without printing secret contents.\n'
fi

remote_check=0
set +e
bash "$ROOT_DIR/scripts/check_release_readiness.sh" \
  --repo "$REPO" \
  --signing-key "$SIGNING_KEY" \
  --kof-archive "$KOF_ARCHIVE"
remote_check=$?
set -e
if (( remote_check != 0 )); then
  cat >&2 <<EOF
Release is not dispatchable yet.
Register both runners at: https://github.com/$REPO/settings/actions/runners/new
Configure environment reviewers at: https://github.com/$REPO/settings/environments
The runner machines and permanent key cannot be fabricated by this script.
EOF
  exit "$remote_check"
fi

(( QUALIFY == 1 )) || exit 0

run_workflow() {
  local publish="$1"
  local run_id=""
  local head_sha
  head_sha="$(gh api "repos/$REPO/commits/main" --jq '.sha')"
  local existing_runs candidate_runs candidate
  existing_runs="$(gh run list --repo "$REPO" --workflow release_demo.yml \
    --event workflow_dispatch --limit 20 --json databaseId \
    --jq '.[].databaseId')"

  gh workflow run release_demo.yml \
    --repo "$REPO" \
    --ref main \
    -f "version=$VERSION" \
    -f "publish=$publish" \
    -f "run_linux_presentation_smoke=$LINUX_SMOKE" \
    -f "run_windows_wine_smoke=$WINDOWS_SMOKE"

  for _ in {1..30}; do
    candidate_runs="$(gh run list --repo "$REPO" --workflow release_demo.yml \
      --event workflow_dispatch --limit 20 --json databaseId,headSha,event \
      --jq "map(select(.headSha == \"$head_sha\" and .event == \"workflow_dispatch\")) | .[].databaseId")"
    while IFS= read -r candidate; do
      [[ -n "$candidate" ]] || continue
      if ! printf '%s\n' "$existing_runs" | grep -Fqx "$candidate"; then
        run_id="$candidate"
        break
      fi
    done <<< "$candidate_runs"
    [[ -n "$run_id" ]] && break
    sleep 2
  done
  [[ -n "$run_id" ]] || fail 'workflow dispatch succeeded but run ID was not found'
  printf 'Watching release workflow run %s (%s).\n' "$run_id" \
    "$([ "$publish" = true ] && printf publish || printf qualification)"
  gh run watch "$run_id" --repo "$REPO" --exit-status
}

run_workflow false
if (( PUBLISH == 1 )); then
  run_workflow true
fi

printf 'Release bootstrap completed for %s.\n' "$VERSION"
