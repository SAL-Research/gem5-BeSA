# SE-mode patches for agent-based modeling (BeSA) workloads

This directory documents the changes this fork carries on top of upstream
gem5 so that complex, multi-threaded C++ applications — BioDynaMo and other
agent-based modeling (ABM) codes in the [BeSA benchmark suite](../README.md)
— run correctly under syscall-emulation (SE) mode.

Items 1–4 below are **already committed** into this fork's source tree
(see `git log src/sim/syscall_emul.cc`, commit `f503703aaf`); they are not
kept as standalone, apply-able `.patch` files, since a BeSA/SE-mode build
requires all of them simultaneously to run at all. They are documented
here so the rationale behind each change stays auditable and so the fix
set can be rebased onto a newer upstream gem5 release. Item 5 is a
separate, standalone artifact (an LD_PRELOAD shim) that ships from this
directory as-is.

## 1. Syscall return-buffer overflow (sockaddr truncation)

**Symptom:** stack corruption and crashes roughly 77–80M instructions into
a BioDynaMo run.

**Bug:** `getsockopt`, `getsocknameFunc`, `acceptFunc`, and `recvfromFunc`
copied back a fixed-size buffer (`sizeof(struct sockaddr)` / the host's
`getsockopt` union) regardless of what the guest actually requested or
what the kernel actually returned. For `AF_NETLINK` sockets the kernel
returns a 12-byte `sockaddr_nl`, but gem5 always wrote 16 bytes back into
the guest's stack buffer, corrupting 4 bytes of adjacent data.

**Fix:** cap every copy-back at
`min(actual host-returned length, guest-supplied buffer length)`.

**Files:** `src/sim/syscall_emul.cc`, `src/sim/syscall_emul.hh`

## 2. Zeroed `AT_RANDOM` auxv entry (spurious stack-canary failures)

**Symptom:** `__stack_chk_fail` aborts on return from ordinary functions.

**Bug:** gem5 SE mode reserves stack space for `AT_RANDOM` — the 16 bytes
glibc uses to seed its per-process stack-canary value — but never wrote
any bytes there, so the canary was always initialized to zero and any
canary check downstream could spuriously fail.

**Fix:** write 16 random bytes to the `AT_RANDOM` address while building
the initial process stack/auxv.

**File:** `src/arch/x86/process.cc`

## 3. Missing syscalls used by BioDynaMo's runtime

**Symptom:** `Unsupported syscall` fatal, or a hang in the threading /
timer-driven progress loop.

**Bug:** BioDynaMo's threading runtime and timer/epoll-based event loop
call `vfork`, `epoll_create1`, `epoll_ctl`, `epoll_wait`,
`timerfd_create`, `timerfd_settime`, and `timerfd_gettime`, none of which
were implemented in the x86-64 SE-mode syscall table.

**Fix:** implement each handler against the host's native epoll/timerfd
calls and wire `vfork` to the existing `clone` emulation (as real glibc
does: `clone(CLONE_VFORK | CLONE_VM | SIGCHLD)`). `epoll_wait` forces a
non-blocking host call (a negative/blocking timeout is clamped to `0`) so
a guest progress loop can never stall the simulator host process; this
means epoll-driven timing is not cycle-accurate, which is an acceptable
trade-off for a functional (non-timing) ABM benchmark run.

**Files:** `src/sim/syscall_emul.cc`, `src/sim/syscall_emul.hh`,
`src/arch/x86/linux/syscall_tbl64.cc`

## 4. Multi-core interrupt controller wiring

**Symptom:** cores other than core 0 silently drop interrupts in
multi-core SE-mode x86 runs.

**Bug:** `BaseCPUCore` only connected the interrupt controller's PIO and
responder ports for `self.core.interrupts[0]`, so any core beyond the
first never had its interrupt controller wired to the rest of the system.

**Fix:** wire every core's interrupt controller, not just the first.

**File:** `src/python/gem5/components/processors/base_cpu_core.py`

## 5. `03-biodynamo-system-shim.c` — LD_PRELOAD shim for `system()`

Not a gem5 patch — a small shim preloaded in front of the *target*
binary. SE mode has no fork/exec support for running an arbitrary host
shell, so BioDynaMo's `system("mkdir -p <dir>")` calls (used to create
output directories) would otherwise crash the simulated process. The
shim overrides `system()` and re-implements that one call pattern with
direct `mkdir()` calls; any other command is logged and ignored rather
than crashing the run.

**Build:**

```sh
cd gem5-patches
make
```

This produces `gem5_system_shim.so`. See [`util/abm/run_se_benchmark.sh`](../util/abm/run_se_benchmark.sh)
for how it is preloaded ahead of a benchmark binary.
