#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"

# Given
# This repository persists orders by writing a local JSON file through writeDb().
# There is no public API to toggle storage failures, no database dependency behind toxiproxy,
# and no supported black-box fault injection seam for filesystem write errors.

# When
printf '%s\n' 'UNSUPPORTED: cannot induce persistence failure for /api/orders via public HTTP APIs only' >&2

# Then
printf '%s\n' 'order_persistence_failure_handled requires non-public fault injection (filesystem/process) that is outside the allowed API-test contract for this repo.' >&2
exit 1

# Cleanup
# No cleanup required.
