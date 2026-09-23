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

`fragments/hardening.config` adds `BUG_ON_DATA_CORRUPTION`, `IO_STRICT_DEVMEM`,
`SLAB_MERGE_DEFAULT=n` and `LEGACY_VSYSCALL_NONE`, all four active on
7.2.7-mirko-mars-2: no `[vsyscall]` mapping, no slab aliases in
`/sys/kernel/slab`; `dmidecode` reads SMBIOS via sysfs and is unaffected.

## Kernel 7.2

The tree is on `linux-rolling-stable` at 7.2.3, the config changes for 7.2 are
merged, and every runtime knob was re-measured on it: `preempt=full`, cpuidle
`menu` and THP `always` all hold, and `SCHED_CACHE` is off — no measurable gain
at 4, 6 or 8 threads against a ~220 ns per-switch cost (see README decisions).
What the measurements turned up along the way:

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

About 80 ns of the 7.2 `pingpong` regression stays unattributed once
`SCHED_CACHE` is accounted for — 4.85 µs on 7.1.12 against 4.93 µs on 7.2.3 with
the mechanism off. Not worth a bisect across 21554 commits.

`amd_x3d_mode` stays `frequency` (see README decisions), although
eight threads sharing a 64 MiB buffer reach 2.2x pinned to the V-Cache CCD and the
scheduler never places them there unpinned. Pin cache-bound jobs to CPUs 0–7,16–23
with `taskset` when they matter.

The `optc401_disable_crtc` `REG_WAIT timeout` warning in the boot log is not
fixed in 7.2 — the only change to `dcn401_optc.c` is an HDMI 2.1 FRL out-mux
mapping, and both monitors here are DisplayPort. Cosmetic, no action.

## Decided against

- Secure Boot / MOK enrollment — no BitLocker, stationary desktop, no threat model
  that SB addresses. See README decisions section.
- Lockdown enforcement (`lockdown=integrity`) — without Secure Boot an attacker
  with root reboots into an unlocked kernel; breaks `/dev/mem`, kexec, hibernation
- `CONFIG_STATIC_USERMODEHELPER=y` — high breakage risk on a desktop
- Disabling `KEXEC`/`KEXEC_FILE` — conflicts with the active `crashkernel=` kdump
  setup in the current cmdline
- GCC plugins (`KSTACK_ERASE`, `RANDSTRUCT`, `LATENT_ENTROPY`) — no gain worth the
  cost here. See README decisions section.
- `debugfs=off` — `/sys/kernel/debug` is already root-only (mode 700), and
  `tools/measure.sh` needs `debug/sched/preempt` and `debug/sched/llc_balancing`
- `init_on_free=1` — `INIT_ON_ALLOC` already runs; the remaining gain is a shorter
  lifetime for freed data, against 1–3% on alloc-heavy work
- `page_alloc.shuffle=1` — the kernel help calls the security gain incidental and
  warns of a cost on platforms without a memory-side cache, which this one lacks
- Re-applying patches after `--clean` and before `--tools` — no patch touches
  `tools/`; the build path applies them before every build
- Sysctl tightening (`dmesg_restrict=1`, `kptr_restrict=2`,
  `kexec_load_disabled=1`) — `mirko` is in `adm`, so `journalctl -k` shows the
  kernel log regardless; `kptr_restrict=1` already hides pointers from non-root;
  kexec restrictions fall with lockdown (root reboots into anything without
  Secure Boot) and would block `kdump-tools` from loading the crash kernel
