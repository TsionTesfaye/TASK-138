#!/bin/bash
# Root-level convenience wrapper. Delegates to scripts/run_tests.sh
set -e
exec "$(dirname "$0")/scripts/run_tests.sh"
