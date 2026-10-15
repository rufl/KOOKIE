#!/usr/bin/env bash

# Keep every local/package gate on the same Kof source and CLI identity.
KOF_PIN_VERSION='0.6.5'
KOF_PIN_CLI_VERSION="kof $KOF_PIN_VERSION"
KOF_PIN_SOURCE_COMMIT='a14a7cd47d74192dcc977c9d4cbf87d407694560'
KOF_PIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KOF_AS_WRAPPER_DIR="$KOF_PIN_ROOT/scripts/kof-as"
if [[ -x "$KOF_AS_WRAPPER_DIR/as" &&
      ":${PATH:-}:" != *":$KOF_AS_WRAPPER_DIR:"* ]]; then
  export PATH="$KOF_AS_WRAPPER_DIR${PATH:+:$PATH}"
fi
export KOF_PIN_VERSION KOF_PIN_CLI_VERSION KOF_PIN_SOURCE_COMMIT \
  KOF_PIN_ROOT KOF_AS_WRAPPER_DIR

kookie_kof_observed() {
  local stage="${1:?kookie_kof_observed: stage name is required}"
  shift
  "$KOF_PIN_ROOT/scripts/kof_observed.sh" \
    --name "$stage" --key "$stage" -- "$@"
}
