# gem5 for Agent-Based Modeling (BeSA fork)

This repository is a fork of the [gem5](http://www.gem5.org) simulator,
patched to support **BeSA** (**Be**nchmarks for **S**imulating **A**gent-based
models in architecture research), a benchmark suite and research effort
carried out at [CISPA Helmholtz Center for Information Security](https://cispa.de)
within the [S4L research group](https://s4lresearch.org/).

Agent-based models — simulators such as [BioDynaMo](https://www.biodynamo.org/)
that advance large populations of interacting agents step by step — are
complex, dynamically-linked, multi-threaded C++ applications. gem5's
syscall-emulation (SE) mode was not originally built with workloads like
these in mind, and running them unmodified exposes several latent bugs and
missing syscalls in upstream gem5. This fork fixes those issues so that
BeSA's ABM traces can be collected and replayed in architecture-research
pipelines. All ABM-specific changes relative to upstream gem5 are isolated
and documented in [`gem5-patches/`](gem5-patches/); pipeline/build helpers
live in [`util/abm/`](util/abm/).

## What's different from upstream gem5

* **SE-mode fixes required for BioDynaMo/BeSA** — a syscall return-buffer
  overflow, a zeroed `AT_RANDOM` auxv entry, missing `epoll`/`timerfd`/
  `vfork` syscalls, and multi-core interrupt-controller wiring. See
  [`gem5-patches/README.md`](gem5-patches/README.md) for the full
  rationale and affected files.
* **`system()` LD_PRELOAD shim** — [`gem5-patches/03-biodynamo-system-shim.c`](gem5-patches/03-biodynamo-system-shim.c)
  lets guest binaries call `system("mkdir -p ...")` under SE mode, which
  has no fork/exec support for an arbitrary host shell.
* **Benchmark-pipeline helpers** — [`util/abm/`](util/abm/) wraps the
  usual scons/`se.py` invocations into two scripts (`build_gem5.sh`,
  `run_se_benchmark.sh`) so an external BeSA sweep driver doesn't need to
  know gem5's build or CLI internals.

Everything else — the simulator core, ISA support, and the rest of the
source tree — is unmodified upstream gem5. For general gem5 documentation,
see <http://www.gem5.org/documentation>.

## Quick start for BeSA benchmarks

```sh
# 1. Build gem5.opt (X86 by default) and the system() shim
util/abm/build_gem5.sh

# 2. Run a benchmark binary in SE mode with the shim preloaded
util/abm/run_se_benchmark.sh \
    --bin /path/to/biodynamo_benchmark \
    --args "--steps 100" \
    --cpu-type TimingSimpleCPU \
    --num-cpus 4 \
    --outdir results/biodynamo_100steps
```

See [`util/abm/README.md`](util/abm/README.md) for all available flags.

## Testing and code coverage status

**Note**: These regard tests run on the develop branch of gem5:
<https://github.com/gem5/gem5/tree/develop>.

[![Daily Tests](https://github.com/gem5/gem5/actions/workflows/daily-tests.yaml/badge.svg?branch=develop)](https://github.com/gem5/gem5/actions/workflows/daily-tests.yaml)
[![Weekly Tests](https://github.com/gem5/gem5/actions/workflows/weekly-tests.yaml/badge.svg?branch=develop)](https://github.com/gem5/gem5/actions/workflows/weekly-tests.yaml)
[![Compiler Tests](https://github.com/gem5/gem5/actions/workflows/compiler-tests.yaml/badge.svg?branch=develop)](https://github.com/gem5/gem5/actions/workflows/compiler-tests.yaml)
[![codecov](https://codecov.io/gh/gem5/gem5/branch/develop/graph/badge.svg)](https://app.codecov.io/gh/gem5/gem5/tree/develop)

## Getting started

A good starting point is <http://www.gem5.org/about>, and for
more information about building the simulator and getting started
please see <http://www.gem5.org/documentation> and
<http://www.gem5.org/documentation/learning_gem5/introduction>.

## Building gem5

To build gem5, you will need the following software: g++ or clang,
Python (gem5 links in the Python interpreter), SCons, zlib, m4, and lastly
protobuf if you want trace capture and playback support. Please see
<http://www.gem5.org/documentation/general_docs/building> for more details
concerning the minimum versions of these tools.

Once you have all dependencies resolved, execute
`scons build/ALL/gem5.opt` to build an optimized version of the gem5 binary
(`gem5.opt`) containing all gem5 ISAs. If you only wish to compile gem5 to
include a single ISA, you can replace `ALL` with the name of the ISA. Valid
options include `ARM`, `NULL`, `MIPS`, `POWER`, `RISCV`, `SPARC`, and `X86`
The complete list of options can be found in the build_opts directory.

See https://www.gem5.org/documentation/general_docs/building for more
information on building gem5.

## The Source Tree

The main source tree includes these subdirectories:

* build_opts: pre-made default configurations for gem5
* build_tools: tools used internally by gem5's build process.
* configs: example simulation configuration scripts
* ext: less-common external packages needed to build gem5
* **gem5-patches**: ABM/BeSA-specific SE-mode fixes and the `system()` shim (fork addition)
* include: include files for use in other programs
* site_scons: modular components of the build system
* src: source code of the gem5 simulator. The C++ source, Python wrappers, and Python standard library are found in this directory.
* system: source for some optional system software for simulated systems
* tests: regression tests
* util: useful utility programs and files, including **util/abm** (fork addition) for driving BeSA benchmark runs

## gem5 Resources

To run full-system simulations, you may need compiled system firmware, kernel
binaries and one or more disk images, depending on gem5's configuration and
what type of workload you're trying to run. Many of these resources can be
obtained from <https://resources.gem5.org>.

More information on gem5 Resources can be found at
<https://www.gem5.org/documentation/general_docs/gem5_resources/>.

## Getting Help, Reporting bugs, and Requesting Features

For questions about the BeSA/ABM-specific changes in this fork — the
SE-mode patches, the `system()` shim, or the `util/abm` pipeline
helpers — see [`gem5-patches/README.md`](gem5-patches/README.md) or
reach out via the [S4L research group](https://s4lresearch.org/) at
CISPA.

For everything else, upstream gem5 provides a variety of channels for
users and developers to get help, report bugs, request features, or
engage in community discussions. Below are a few of the most common we
recommend using.

* **GitHub Discussions**: A GitHub Discussions page. This can be used to start
discussions or ask questions. Available at
<https://github.com/orgs/gem5/discussions>.
* **GitHub Issues**: A GitHub Issues page for reporting bugs or requesting
features. Available at <https://github.com/gem5/gem5/issues>.
* **Jira Issue Tracker**: A Jira Issue Tracker for reporting bugs or requesting
features. Available at <https://gem5.atlassian.net/>.
* **Slack**: A Slack server with a variety of channels for the gem5 community
to engage in a variety of discussions. Please visit
<https://www.gem5.org/join-slack> to join.
* **gem5-users@gem5.org**: A mailing list for users of gem5 to ask questions
or start discussions. To join the mailing list please visit
<https://www.gem5.org/mailing_lists>.
* **gem5-dev@gem5.org**: A mailing list for developers of gem5 to ask questions
or start discussions. To join the mailing list please visit
<https://www.gem5.org/mailing_lists>.

## Contributing to gem5

We hope you enjoy using gem5. When appropriate we advise sharing your
contributions to the project. <https://www.gem5.org/contributing> can help you
get started. Additional information can be found in the CONTRIBUTING.md file.
