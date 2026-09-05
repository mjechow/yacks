# TODO

## Hardening

Baseline (`old/config-7.1.12-mirko-mars`) already carries the Ubuntu mainline hardening
set: KASLR (base/memory/kstack-offset), `STACKPROTECTOR_STRONG`, `VMAP_STACK`,
`FORTIFY_SOURCE`, `HARDENED_USERCOPY` (+default-on), `SLAB_FREELIST_HARDENED`,
`SLAB_FREELIST_RANDOM`, `SHUFFLE_PAGE_ALLOCATOR`, `INIT_ON_ALLOC_DEFAULT_ON`,
`LIST_HARDENED`, `ZERO_CALL_USED_REGS`, `STRICT_KERNEL_RWX`, `STRICT_MODULE_RWX`,
`STRICT_DEVMEM`, `LEGACY_VSYSCALL_XONLY`, `BPF_UNPRIV_DEFAULT_OFF`,
`BPF_JIT_ALWAYS_ON`, all 13 `MITIGATION_*`, LSM stack
`landlock,lockdown,yama,integrity,apparmor`, `X86_X32_ABI` and `COMPAT_VDSO` off.

The items below are the remaining gaps.

### Tier 1 — config, no measurable cost

- [ ] Create `fragments/hardening.config` and register it in the `FRAGMENT_FILES`
      array in `buildKernel.sh` (list is hardcoded, ~line 216)
- [ ] `CONFIG_BUG_ON_DATA_CORRUPTION=y` — `LIST_HARDENED` checks already run;
      this turns a detected corruption into a panic instead of a warning
- [ ] `CONFIG_IO_STRICT_DEVMEM=y` — blocks `/dev/mem` access to MMIO regions an
      active driver claims; verify `dmidecode` still works after boot
- [ ] Verify every option landed in `config-<ver>-mirko-mars.diff` after the build

### Tier 2 — kernel cmdline, no rebuild, revertible from the GRUB editor

Test via one-shot GRUB edit first, then persist in `/etc/default/grub`.

- [ ] `slab_nomerge` — stops slab cache merging, raises the bar for heap grooming
- [ ] `init_on_free=1` — same effect as `INIT_ON_FREE_DEFAULT_ON` without a
      rebuild; measure before making it permanent (1–3% on alloc-heavy work)
- [ ] `debugfs=off` — removes the debugfs attack surface; check nothing in the
      AMDGPU/Mint stack depends on it
- [ ] `page_alloc.shuffle=1` — force-enable the already-compiled-in freelist
      randomization
- [ ] `vsyscall=none` — hardens the `XONLY` default further; only relevant if no
      pre-2013 static binaries are in use

### Tier 3 — GCC plugins, build complexity

Blocked on `gcc-15-plugin-dev` (not installed; installable from the PPA) plus
`CONFIG_GCC_PLUGINS=y`. `CC_HAS_RANDSTRUCT` and
`CC_HAS_SANCOV_STACK_DEPTH_CALLBACK` are both absent, so the Clang paths are not
available — plugins are the only route.

- [ ] Decide whether Tier 3 is worth the build complexity at all
- [ ] `CONFIG_KSTACK_ERASE=y` (former `STACKLEAK`) — erases the kernel stack on
      syscall return, kills stack-content infoleaks; ~1% cost. Best single gain
      of the plugin options
- [ ] `CONFIG_RANDSTRUCT_FULL=y` — needs `select MODVERSIONS` (currently off),
      and the seed in `scripts/basic/randomize.seed` must survive across builds
      or out-of-tree modules break
- [ ] Fix seed persistence before enabling `RANDSTRUCT`: `--clean` runs
      `git clean -dfx` in the kernel tree (`buildKernel.sh:47`), which deletes
      `scripts/basic/randomize.seed` — same class of bug as the module signing key

## Kernel 7.2

The tree is on `linux-rolling-stable` at 7.2.3, the config changes for 7.2 are
merged, and every runtime knob was re-measured on it: `preempt=full`, cpuidle
`menu` and THP `always` all hold, and `SCHED_CACHE` is off — no measurable gain
at 4, 6 or 8 threads against a ~220 ns per-switch cost (see README decisions).
What the measurements turned up along the way:

- [ ] Try `amd_x3d_mode=cache` for working sets between 32 and 96 MB. Eight
      threads sharing a 64 MiB buffer reach 1565 M ops/s pinned to the V-Cache
      CCD against 703 M ops/s pinned to the other one — 2.2x — and nothing puts
      them there on its own: the scheduler favours the higher-clocking CCD (CPPC
      `highest_perf` 226-231 against 176-181) and left every unpinned run on it.
      The mode is a runtime knob
      (`/sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode`), so the change
      belongs in `mars-config`, not here — but the default `frequency` mode
      demonstrably costs more than half the throughput on cache-resident work.
- [ ] Send a `Tested-by` for the PROM21 600-series patch, and consider respinning
      it as v3. Confirmed working on this X670E with 7.2.3-mirko-mars-4: both
      `[1022:43f7]` functions bind `xhci-pci-prom21`, both auxiliary devices
      appear, `sensors` reports 57.4 °C and 62.8 °C against 58 °C Tctl, and USB
      is unaffected. That is a second board after the submitter's X670. The only
      review comment on the thread asks for the new IDs to be added to the
      `PCI IDs:` line in `Documentation/hwmon/prom21-xhci.rst`, so a v3 is owed
      and nobody has sent one — worth doing, since the patch is carried locally
      until it lands. Thread:
      <https://patchwork.kernel.org/project/linux-usb/patch/20260820-xhci-pci-prom21-v2-1-638e5958fbbf@stevetech.au/>
- [ ] Find out where the `SCHED_CACHE` misplacement decision is made, then
      decide whether it is worth reporting. Reproducer: ten consecutive
      `tools/knobbench spread 24 8` runs with `llc_balancing/enabled=1` place
      threads across both CCDs in 5, 5 and 7 of 10 across three blocks, against
      0 of 20 with it disabled and 0 of 10 when alternated with disabled runs.
      Needs a kernel with the symbol compiled in — `7.2.3-mirko-mars-2` while it
      lasts, otherwise a build for the purpose. Machine is a 7950X3D, two LLCs,
      single NUMA node, `numa_balancing=0`, and the per-LLC counters look
      correctly paired, so the cause is open.
      Three steps need no rebuild. `kernel.sched_schedstats=1` (compiled in, off
      at runtime), then diff `/proc/schedstat` around a block: domain lines carry
      45 counters in three groups of 11, field 8 of each group being the
      `detach_task` count, so `domain2 PKG` detaches during enabled blocks and
      none during disabled ones would put the cross-CCD moves on the periodic
      balancer via `migrate_llc_task`, with `alb_pushed` separating active
      balance. A placement timeline in `spread` — workers publishing their CPU
      each chunk, a monitor sampling every 10 ms — says when: a split appearing
      within the first tens of milliseconds and never healing implicates
      `task_cache_work()`, given the 10 ms epoch and 50 ms affinity timeout,
      while one that oscillates does not. And the knobs bisect the stages:
      `aggr_tolerance` gates `invalid_llc_nr()`, `epoch_period` how often the
      preference is recomputed, `epoch_affinity_timeout` when a stale one is
      dropped, `imb_pct` and `overaggr_pct` the balancer's willingness to act.
      For an upstream report the evidence wants to be kernel-side: a build with
      `FTRACE=y` and `FUNCTION_TRACER=n` (tracepoints at NOP cost, see README
      decisions) plus `SCHED_DEBUG`, recording `sched_migrate_task` and
      `sched_wakeup_new`. Keep that under its own `REV`, not as the daily kernel.
- [ ] Tier 2's `debugfs=off` also takes `/sys/kernel/debug/sched/preempt` with
      it, which `tools/measure.sh` needs for the preemption comparison. Measure
      first, harden after.

About 80 ns of the 7.2 `pingpong` regression stays unattributed once
`SCHED_CACHE` is accounted for — 4.85 µs on 7.1.12 against 4.93 µs on 7.2.3 with
the mechanism off. Not worth a bisect across 21554 commits.

The `optc401_disable_crtc` `REG_WAIT timeout` warning in the boot log is not
fixed in 7.2 — the only change to `dcn401_optc.c` is an HDMI 2.1 FRL out-mux
mapping, and both monitors here are DisplayPort. Cosmetic, no action.

## Build script

- [ ] Simplify the Ubuntu `.deb` lookup in `buildKernel.sh`, around the
      `DEB_FILE=` assignment. The `|| warn` there can never fire: the assignment
      takes the pipeline's exit status, which is `head`'s, and `head` exits 0 even
      when `grep` matched nothing. The block after it then warns a second time and
      assigns `""` to a variable that is already empty. Seven lines collapse to
      the assignment plus `[[ -n "$DEB_FILE" ]] || warn ...`, which also makes the
      download-failure path testable by pointing `UBUNTU_BASE_URL` at a 404.

## Out of scope for this repo

- [ ] Sysctl gaps belong in `mars-config` (`bare-metal/sysctl/`), not YACKS:
      `kernel.dmesg_restrict=0` despite `SECURITY_DMESG_RESTRICT=y` in the config,
      `kernel.kptr_restrict=1` (2 is stricter), `kernel.kexec_load_disabled=0`

## Decided against

- Secure Boot / MOK enrollment — no BitLocker, stationary desktop, no threat model
  that SB addresses. See README decisions section.
- Lockdown enforcement (`lockdown=integrity`) — without Secure Boot an attacker
  with root reboots into an unlocked kernel; breaks `/dev/mem`, kexec, hibernation
- `CONFIG_STATIC_USERMODEHELPER=y` — high breakage risk on a desktop
- Disabling `KEXEC`/`KEXEC_FILE` — conflicts with the active `crashkernel=` kdump
  setup in the current cmdline
