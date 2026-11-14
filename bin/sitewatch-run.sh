#!/usr/bin/env bash
# Backwards-compatible alias for early group integrations.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/sitewatch.sh" "$@"
