#!/usr/bin/env bash
set -euo pipefail

"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build.sh"

"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build/sagasu-menubar"