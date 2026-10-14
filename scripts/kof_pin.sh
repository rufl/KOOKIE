#!/usr/bin/env bash

# Keep every local/package gate on the same Kof source and CLI identity.
KOF_PIN_VERSION='0.6.5'
KOF_PIN_CLI_VERSION="kof $KOF_PIN_VERSION"
KOF_PIN_SOURCE_COMMIT='940f3bd81c25e564afc60f9d32d49652e47edcbc'
KOF_PIN_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
KOF_AS_WRAPPER_DIR="$KOF_PIN_ROOT/scripts/kof-as"
if [[ -x "$KOF_AS_WRAPPER_DIR/as" &&
      ":${PATH:-}:" != *":$KOF_AS_WRAPPER_DIR:"* ]]; then
  export PATH="$KOF_AS_WRAPPER_DIR${PATH:+:$PATH}"
fi
export KOF_PIN_VERSION KOF_PIN_CLI_VERSION KOF_PIN_SOURCE_COMMIT \
  KOF_PIN_ROOT KOF_AS_WRAPPER_DIR
