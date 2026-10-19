# ABM benchmark-pipeline helpers

Thin wrapper scripts around the standard gem5 build/run flow, aimed at
driving this fork from an external benchmark-suite pipeline (BeSA)
without every job having to know scons flags or `se.py` arguments.

* `build_gem5.sh` — builds `gem5.opt` for a given ISA (default `X86`) and
  the BioDynaMo `system()` shim from [`../gem5-patches/`](../gem5-patches/)
  in one step.
* `run_se_benchmark.sh` — runs a single benchmark binary in SE mode with
  that shim preloaded into the guest process. Intended to be called once
  per benchmark/configuration by a sweep driver; CPU model, core count,
  binary, and arguments are all flags, and each invocation writes its
  stats to its own `--outdir`.

See [`../gem5-patches/README.md`](../gem5-patches/README.md) for what the
shim does and why it, and the other SE-mode fixes in this fork, exist.

Example:

```sh
util/abm/build_gem5.sh X86 -j8
util/abm/run_se_benchmark.sh \
    --bin /path/to/biodynamo_benchmark \
    --args "--steps 100" \
    --cpu-type TimingSimpleCPU \
    --num-cpus 4 \
    --outdir results/biodynamo_100steps
```
