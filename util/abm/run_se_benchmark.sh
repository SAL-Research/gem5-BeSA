#!/usr/bin/env bash
# Run one ABM (BeSA) benchmark binary under this fork's gem5 in
# syscall-emulation (SE) mode, with the BioDynaMo system() shim preloaded
# into the guest process.
#
# This is a template entry point for a benchmark-suite driver: adjust the
# defaults below (CPU model, core count) to match your sweep, or override
# them with flags.
#
# Usage:
#   util/abm/run_se_benchmark.sh --bin /path/to/benchmark [--args "..."] \
#       [--outdir results/run1] [--cpu-type TimingSimpleCPU] [--num-cpus 4] \
#       [--gem5-opt build/X86/gem5.opt] [--shim gem5-patches/gem5_system_shim.so]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BIN=""
ARGS=""
OUTDIR="m5out"
CPU_TYPE="TimingSimpleCPU"
NUM_CPUS=1
GEM5_OPT="$REPO_ROOT/build/X86/gem5.opt"
SHIM="$REPO_ROOT/gem5-patches/gem5_system_shim.so"
SE_CONFIG="$REPO_ROOT/configs/deprecated/example/se.py"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bin) BIN="$2"; shift 2 ;;
        --args) ARGS="$2"; shift 2 ;;
        --outdir) OUTDIR="$2"; shift 2 ;;
        --cpu-type) CPU_TYPE="$2"; shift 2 ;;
        --num-cpus) NUM_CPUS="$2"; shift 2 ;;
        --gem5-opt) GEM5_OPT="$2"; shift 2 ;;
        --shim) SHIM="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$BIN" ]]; then
    echo "Usage: $0 --bin /path/to/benchmark [--args \"...\"] [options]" >&2
    exit 1
fi
if [[ ! -x "$GEM5_OPT" ]]; then
    echo "gem5 binary not found at $GEM5_OPT (run util/abm/build_gem5.sh first)" >&2
    exit 1
fi
if [[ ! -f "$SHIM" ]]; then
    echo "Warning: shim not found at $SHIM; BioDynaMo-style system() calls" >&2
    echo "         (e.g. 'mkdir -p ...') will crash the simulated process." >&2
fi

mkdir -p "$OUTDIR"

# SE mode reads the guest process's environment from a file (-e/--env);
# this is what a dynamically-linked guest's own loader honors LD_PRELOAD
# from, equivalent to `LD_PRELOAD=$SHIM ./binary` on real Linux.
ENV_FILE="$(mktemp)"
trap 'rm -f "$ENV_FILE"' EXIT
if [[ -f "$SHIM" ]]; then
    echo "LD_PRELOAD=$SHIM" > "$ENV_FILE"
fi

echo "== Running $(basename "$BIN") =="
echo "   cpu-type: $CPU_TYPE   num-cpus: $NUM_CPUS   outdir: $OUTDIR"

"$GEM5_OPT" --outdir="$OUTDIR" "$SE_CONFIG" \
    --cpu-type="$CPU_TYPE" \
    --num-cpus="$NUM_CPUS" \
    --cmd="$BIN" \
    --options="$ARGS" \
    --env="$ENV_FILE"
