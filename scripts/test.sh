#!/usr/bin/env bash
set -euo pipefail

TOOLCHAIN="$(dirname "$(dirname "$(xcrun --find swift)")")"
exec swift test -Xswiftc -plugin-path -Xswiftc "$TOOLCHAIN/lib/swift/host/plugins/testing" "$@"
