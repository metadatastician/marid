#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# check-package-manager.sh - every tracked package.json under web/ and
# examples/relationship_explorer/ must declare "packageManager": "bun@<v>",
# where <v> is the Bun version CI pins in .github/workflows/web-ci.yml
# (`bun-version:`). That workflow file is the single comparison source.
#
# Usage: check-package-manager.sh [REPO_ROOT]   (default: .)
# Exit 0 when all files match; 1 with one line per offending file; 2 on setup error.

set -euo pipefail

ROOT="${1:-.}"
WORKFLOW="$ROOT/.github/workflows/web-ci.yml"

if [ ! -f "$WORKFLOW" ]; then
    echo "ERROR: workflow not found: $WORKFLOW" >&2
    exit 2
fi

pinned=$(sed -n -E "s/^[[:space:]]*bun-version:[[:space:]]*['\"]?([0-9][0-9A-Za-z.+-]*)['\"]?[[:space:]]*(#.*)?$/\1/p" "$WORKFLOW" | sort -u)
if [ -z "$pinned" ] || [ "$(printf '%s\n' "$pinned" | wc -l)" -ne 1 ]; then
    echo "ERROR: expected exactly one exact bun-version in $WORKFLOW, found: ${pinned:-none}" >&2
    exit 2
fi

files=$(git -C "$ROOT" ls-files -- 'web/**package.json' 'web/package.json' \
    'examples/relationship_explorer/**package.json' 'examples/relationship_explorer/package.json' \
    | grep -E '(^|/)package\.json$' | grep -v 'node_modules/' | sort -u)
if [ -z "$files" ]; then
    echo "ERROR: no tracked package.json found under web/ or examples/relationship_explorer/" >&2
    exit 2
fi

fail=0
count=0
while IFS= read -r f; do
    count=$((count + 1))
    declared=$(sed -n -E 's/^[[:space:]]*"packageManager":[[:space:]]*"([^"]*)".*$/\1/p' "$ROOT/$f" | head -n 1)
    if [ -z "$declared" ]; then
        echo "FAIL: $f: missing \"packageManager\" (expected bun@$pinned)"
        fail=1
    elif [ "$declared" != "bun@$pinned" ]; then
        echo "FAIL: $f: packageManager is \"$declared\", CI pins bun@$pinned"
        fail=1
    fi
done <<< "$files"

if [ "$fail" -ne 0 ]; then
    exit 1
fi
echo "PASS: $count package.json files declare packageManager bun@$pinned"
