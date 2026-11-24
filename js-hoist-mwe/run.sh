#!/usr/bin/env bash
# Build model.R to JavaScript with odin2 as it is on odin2-js-wip (BASE) and with this branch, then benchmark both.
#   ./run.sh                 # base commit ff5d050 (odin2-js-wip when this was written)
#   BASE=origin/odin2-js-wip ./run.sh
# Needs R (with odin2's dependencies installed) and node >= 18.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$(git rev-parse --show-toplevel)
BASE=${BASE:-ff5d050}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== installing odin2 at $BASE (current approach) and at this checkout (hoisted)"
mkdir -p "$TMP/src_before" "$TMP/lib_before" "$TMP/lib_after"
git -C "$ROOT" archive "$BASE" | tar -x -C "$TMP/src_before"
R CMD INSTALL --no-test-load -l "$TMP/lib_before" "$TMP/src_before" > "$TMP/install_before.log" 2>&1
R CMD INSTALL --no-test-load -l "$TMP/lib_after" "$ROOT" > "$TMP/install_after.log" 2>&1

echo "== generating JavaScript"
R_LIBS="$TMP/lib_before${R_LIBS:+:$R_LIBS}" Rscript generate.R model_before.mjs
R_LIBS="$TMP/lib_after${R_LIBS:+:$R_LIBS}" Rscript generate.R model_after.mjs

echo "== benchmarking"
[ -d node_modules ] || npm install --no-audit --no-fund --silent
node bench.mjs "$@"
