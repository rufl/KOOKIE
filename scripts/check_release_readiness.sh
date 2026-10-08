#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO="${GITHUB_REPOSITORY:-rufl/KOOKIE}"
SIGNING_KEY="${KOOKIE_SIGNING_KEY:-}"
KOF_ARCHIVE="${KOOKIE_KOF_ARCHIVE:-}"
CHECK_GITHUB=1
SET_GITHUB_SECRETS=0

usage() {
  cat <<'EOF'
Usage: scripts/check_release_readiness.sh [options]

Checks the local signing identity, pinned Kof archive and GitHub release
prerequisites without printing secret contents. With --set-github-secrets it
updates KOOKIE_SIGNING_KEY_PEM and KOOKIE_KOF_ARCHIVE_SHA256 in the repository.

Options:
  --repo OWNER/REPO       GitHub repository (default: rufl/KOOKIE)
  --signing-key PATH      owner-controlled Ed25519 private key
  --kof-archive PATH      exact Kof 0.5.0-beta distribution archive
  --skip-github           only validate local release inputs
  --set-github-secrets    upload the validated inputs to GitHub Actions
  --help                  show this help
EOF
}

while (($#)); do
  case "$1" in
    --repo) REPO="${2:?missing repository}"; shift 2 ;;
    --signing-key) SIGNING_KEY="${2:?missing signing key}"; shift 2 ;;
    --kof-archive) KOF_ARCHIVE="${2:?missing Kof archive}"; shift 2 ;;
    --skip-github) CHECK_GITHUB=0; shift ;;
    --set-github-secrets) SET_GITHUB_SECRETS=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "check_release_readiness: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if (( SET_GITHUB_SECRETS == 1 && CHECK_GITHUB == 0 )); then
  echo 'check_release_readiness: --set-github-secrets requires GitHub checks' >&2
  exit 2
fi

for command_name in cut grep openssl sha256sum stat; do
  command -v "$command_name" >/dev/null || {
    echo "check_release_readiness: $command_name is required" >&2
    exit 2
  }
done

failures=0

if [[ -z "$SIGNING_KEY" ]]; then
  echo 'BLOCKED: --signing-key is required; do not use the ephemeral qualification key' >&2
  failures=$((failures + 1))
elif [[ "$SIGNING_KEY" == /tmp/kookie-release-qualification.pem ]]; then
  echo 'BLOCKED: the ephemeral qualification key cannot configure a public release' >&2
  failures=$((failures + 1))
elif [[ ! -f "$SIGNING_KEY" || -L "$SIGNING_KEY" ]]; then
  echo "BLOCKED: signing key is not a regular file: $SIGNING_KEY" >&2
  failures=$((failures + 1))
else
  key_mode="$(stat -c '%a' "$SIGNING_KEY")"
  if (( (8#$key_mode & 077) != 0 )); then
    echo "BLOCKED: signing key permissions must exclude group/other access: $SIGNING_KEY" >&2
    failures=$((failures + 1))
  fi
  if ! openssl pkey -in "$SIGNING_KEY" -text -noout 2>/dev/null |
      grep -Fq ED25519; then
    echo "BLOCKED: signing key is not a readable Ed25519 key: $SIGNING_KEY" >&2
    failures=$((failures + 1))
  fi
fi

if [[ -z "$KOF_ARCHIVE" ]]; then
  echo 'BLOCKED: --kof-archive is required' >&2
  failures=$((failures + 1))
elif [[ ! -f "$KOF_ARCHIVE" || -L "$KOF_ARCHIVE" ]]; then
  echo "BLOCKED: Kof archive is not a regular file: $KOF_ARCHIVE" >&2
  failures=$((failures + 1))
fi

kof_sha256=""
if [[ -f "$KOF_ARCHIVE" && ! -L "$KOF_ARCHIVE" ]]; then
  kof_sha256="$(sha256sum "$KOF_ARCHIVE" | cut -d ' ' -f 1)"
  printf 'Kof archive SHA-256: %s\n' "$kof_sha256"
fi
local_failures="$failures"
github_authenticated=0
if (( CHECK_GITHUB == 1 )); then
  command -v gh >/dev/null || {
    echo 'check_release_readiness: gh is required for GitHub checks' >&2
    exit 2
  }
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    github_authenticated=1
  else
    echo 'BLOCKED: gh is not authenticated for github.com' >&2
    failures=$((failures + 1))
  fi

  secret_names="$(gh secret list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null || true)"
  for required_secret in KOOKIE_SIGNING_KEY_PEM KOOKIE_KOF_ARCHIVE_SHA256; do
    if ! printf '%s\n' "$secret_names" | grep -Fqx "$required_secret"; then
      echo "BLOCKED: GitHub secret is missing: $REPO/$required_secret" >&2
      failures=$((failures + 1))
    fi
  done

  runners="$(gh api "repos/$REPO/actions/runners" --paginate \
    --jq '.runners[] | [.name,.status,(.labels | map(.name | ascii_downcase) | join(","))] | @tsv' \
    2>/dev/null || true)"
  linux_runner=0
  windows_runner=0
  while IFS=$'\t' read -r _ runner_status runner_labels; do
    [[ "$runner_status" == online &&
       ",$runner_labels," == *",self-hosted,"* &&
       ",$runner_labels," == *",x64,"* &&
       ",$runner_labels," == *",kookie-demo-release,"* ]] || continue
    [[ ",$runner_labels," == *",linux,"* ]] && linux_runner=1
    [[ ",$runner_labels," == *",windows,"* ]] && windows_runner=1
  done <<< "$runners"
  if (( linux_runner == 0 )); then
    echo "BLOCKED: online Linux release runner labels are missing in $REPO" >&2
    failures=$((failures + 1))
  fi
  if (( windows_runner == 0 )); then
    echo "BLOCKED: online Windows release runner labels are missing in $REPO" >&2
    failures=$((failures + 1))
  fi

  if ! gh api "repos/$REPO/environments/kookie-demo-release" >/dev/null 2>&1; then
    echo "BLOCKED: GitHub environment is missing: $REPO/kookie-demo-release" >&2
    failures=$((failures + 1))
  fi

  if (( SET_GITHUB_SECRETS == 1 &&
        local_failures == 0 && github_authenticated == 1 )); then
    gh secret set KOOKIE_SIGNING_KEY_PEM --repo "$REPO" < "$SIGNING_KEY"
    gh secret set KOOKIE_KOF_ARCHIVE_SHA256 --repo "$REPO" --body "$kof_sha256"
    echo "GitHub secrets updated: $REPO"
  elif (( SET_GITHUB_SECRETS == 1 )); then
    echo 'GitHub secrets were not changed because readiness checks failed.' >&2
  fi
fi

if (( failures != 0 )); then
  printf 'Release readiness: BLOCKED (%s issue(s))\n' "$failures" >&2
  exit 1
fi

echo 'Release readiness: PASS'
