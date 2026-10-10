#!/usr/bin/env bash

# Keep every local/package gate on the same immutable Kof distribution.
KOF_PIN_VERSION='0.5.0-beta'
KOF_PIN_CLI_VERSION="kof $KOF_PIN_VERSION"
KOF_PIN_SOURCE_COMMIT='bf17ac7e736471c8a04b4153e5b0f607be75e70c'
export KOF_PIN_VERSION KOF_PIN_CLI_VERSION KOF_PIN_SOURCE_COMMIT
