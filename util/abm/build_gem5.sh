#!/usr/bin/env bash
# Build this fork's gem5.opt binary plus the BioDynaMo system() shim.
#
# Usage: util/abm/build_gem5.sh [ISA] [-j N]
#   ISA   gem5 ISA target (default: X86)
#   -j N  parallel build jobs (default: nproc)
#
# Run from anywhere; paths are resolved relative to the repo root.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ISA="X86"
JOBS="$(nproc 2>/dev/null || echo 4)"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -j) JOBS="$2"; shift 2 ;;
        *) ISA="$1"; shift ;;
    esac
done

echo "== Building gem5.opt (${ISA}) with -j${JOBS} =="
( cd "$REPO_ROOT" && scons "build/${ISA}/gem5.opt" "-j${JOBS}" )

echo "== Building gem5_system_shim.so =="
( cd "$REPO_ROOT/gem5-patches" && make )

echo "== Done =="
echo "gem5 binary: $REPO_ROOT/build/${ISA}/gem5.opt"
echo "shim:        $REPO_ROOT/gem5-patches/gem5_system_shim.so"
