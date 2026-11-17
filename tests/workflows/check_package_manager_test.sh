#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

CHECKER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/check-package-manager.sh"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name "RSR fixture"
git -C "$FIXTURE" config user.email "fixture@example.invalid"

mkdir -p "$FIXTURE/.github/workflows" "$FIXTURE/web/client" "$FIXTURE/examples/relationship_explorer"
printf "      - uses: x\n        with:\n          bun-version: '9.9.9'\n" > "$FIXTURE/.github/workflows/web-ci.yml"
for d in web web/client examples/relationship_explorer; do
    printf '{\n  "name": "x",\n  "packageManager": "bun@9.9.9",\n  "license": "MPL-2.0"\n}\n' > "$FIXTURE/$d/package.json"
done
git -C "$FIXTURE" add -A

"$CHECKER" "$FIXTURE" | grep -q '^PASS:'

# Untracked / node_modules copies must be ignored.
mkdir -p "$FIXTURE/web/node_modules/p"
printf '{}\n' > "$FIXTURE/web/node_modules/p/package.json"
git -C "$FIXTURE" add -f web/node_modules/p/package.json
"$CHECKER" "$FIXTURE" | grep -q '^PASS:'
git -C "$FIXTURE" rm -q -f web/node_modules/p/package.json

# Missing field.
printf '{\n  "name": "x"\n}\n' > "$FIXTURE/web/client/package.json"
if "$CHECKER" "$FIXTURE" > "$FIXTURE/out" 2>&1; then
    echo "FAIL: checker accepted a missing packageManager" >&2
    exit 1
fi
grep -q '^FAIL: web/client/package.json: missing' "$FIXTURE/out"
test "$(grep -c '^FAIL:' "$FIXTURE/out")" -eq 1

# Version differs.
printf '{\n  "packageManager": "bun@1.0.0"\n}\n' > "$FIXTURE/web/client/package.json"
if "$CHECKER" "$FIXTURE" > "$FIXTURE/out" 2>&1; then
    echo "FAIL: checker accepted a mismatched version" >&2
    exit 1
fi
grep -q 'web/client/package.json: packageManager is "bun@1.0.0", CI pins bun@9.9.9' "$FIXTURE/out"

# A compact one-line manifest is valid JSON and must pass.
printf '{"name":"x","packageManager":"bun@9.9.9"}\n' > "$FIXTURE/web/client/package.json"
"$CHECKER" "$FIXTURE" | grep -q '^PASS:'

# A nested packageManager must not stand in for a missing root one.
printf '{\n  "name": "x",\n  "config": {\n    "packageManager": "bun@9.9.9"\n  }\n}\n' > "$FIXTURE/web/client/package.json"
if "$CHECKER" "$FIXTURE" > "$FIXTURE/out" 2>&1; then
    echo "FAIL: checker accepted a nested packageManager with no root one" >&2
    exit 1
fi
grep -q '^FAIL: web/client/package.json: missing' "$FIXTURE/out"

# A manifest that is not valid JSON is reported, not skipped.
printf '{ not json\n' > "$FIXTURE/web/client/package.json"
if "$CHECKER" "$FIXTURE" > "$FIXTURE/out" 2>&1; then
    echo "FAIL: checker accepted an invalid manifest" >&2
    exit 1
fi
grep -q '^FAIL: web/client/package.json: not valid JSON' "$FIXTURE/out"

echo "PASS: check-package-manager tests"
