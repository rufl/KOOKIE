#!/usr/bin/env bash

# Keep every local/package gate on the same Kof source and CLI identity.
KOF_PIN_VERSION='0.6.6'
KOF_PIN_CLI_VERSION="kof $KOF_PIN_VERSION"
KOF_PIN_SOURCE_COMMIT='7c237861a9035d84b1f7ec4cfddd89daef4c6ddd'
KOF_PIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KOF_AS_WRAPPER_DIR="$KOF_PIN_ROOT/scripts/kof-as"
kookie_prepend_path() {
  local directory="$1"
  if [[ "${PATH:-}" == "$directory" ||
        "${PATH:-}" == "$directory:"* ]]; then
    return
  fi
  export PATH="$directory${PATH:+:$PATH}"
}
if [[ -n "${KOOKIE_KOF_BIN_DIR:-}" &&
      -x "$KOOKIE_KOF_BIN_DIR/kof" ]]; then
  kookie_prepend_path "$KOOKIE_KOF_BIN_DIR"
fi
if [[ -x "$KOF_AS_WRAPPER_DIR/as" ]]; then
  kookie_prepend_path "$KOF_AS_WRAPPER_DIR"
fi
export KOF_PIN_VERSION KOF_PIN_CLI_VERSION KOF_PIN_SOURCE_COMMIT \
  KOF_PIN_ROOT KOF_AS_WRAPPER_DIR

kookie_kof_observed() {
  local stage="${1:?kookie_kof_observed: stage name is required}"
  shift
  local stage_key="${stage^^}"
  stage_key="${stage_key//[^A-Z0-9]/_}"
  local timeout_var="KOOKIE_KOF_BUILD_TIMEOUT_${stage_key}_SECONDS"
  local estimate_var="KOOKIE_KOF_BUILD_ESTIMATE_${stage_key}_SECONDS"
  local -a observer_args=(--name "$stage" --key "$stage")
  if [[ -n "${!timeout_var:-}" ]]; then
    observer_args+=(--timeout "${!timeout_var}")
  fi
  if [[ -n "${!estimate_var:-}" ]]; then
    observer_args+=(--estimate-seconds "${!estimate_var}")
  fi
  "$KOF_PIN_ROOT/scripts/kof_observed.sh" \
    "${observer_args[@]}" -- "$@"
}
