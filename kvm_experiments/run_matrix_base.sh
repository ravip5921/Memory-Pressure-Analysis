#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/run_base.sh"
"$SCRIPT_DIR/run_matrix.sh"

echo "Baseline + matrix run complete."
