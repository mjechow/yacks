# TODO

## Hardening

Baseline (`config-7.1.9-mirko-mars`) already carries the Ubuntu mainline hardening
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

## Kernel 7.2 — after the branch bump

The tree tracks `linux-rolling-stable`, so 7.2.x arrives on its own once the
stable releases land. Everything below was verified against the `v7.2` tag, which
is already present locally — none of it exists in 7.1.12.

- [ ] `CONFIG_SCHED_CACHE=y` in `base.config`. Cache-aware load balancing pulls
      threads of one process onto a single LLC domain. Directly relevant here:
      the 7950X3D has two CCDs with asymmetric L3 — 96 MB on CPUs 0-7,16-23
      versus 32 MB on 8-15,24-31. `init/Kconfig:1025`, `default y`,
      `depends on SMP`, and active at runtime by default
      (`sysctl_sched_cache_user = 1` in `kernel/sched/fair.c:857`). It comes in
      from the Ubuntu base regardless — pin it explicitly like every other
      scheduling option in that fragment.
- [ ] Re-measure with `tools/knobbench` after the bump. `SCHED_CACHE`
      changes placement, so the `pingpong` and `tlb` baselines from 7.1.9 no
      longer apply. Tuning knobs sit in debugfs, not sysctl:
      `/sys/kernel/debug/sched/llc_balancing/{enabled,aggr_tolerance,epoch_period,epoch_affinity_timeout,overaggr_pct,imb_pct}`
      (`kernel/sched/debug.c:672`, guarded by `#ifdef CONFIG_SCHED_CACHE`, root only).
- [ ] Resolve the conflict with Tier 2 above: `debugfs=off` removes those knobs.
      Tune first, harden after — or skip `debugfs=off`.
- [ ] Re-check `preempt=lazy` and the cpuidle governor after the bump. Both were
      rejected on 7.1.9 measurements (see README decisions); 7.2 touches the
      scheduler, so the numbers are not transferable.
- [ ] `CONFIG_SENSORS_PROM21_XHCI=m` in the HWMON block of
      `cpu-amd-zen4.config`, next to `NCT6683` and `K10TEMP`. New in 7.2:
      "AMD Promontory 21 xHCI temperature sensor", `depends on USB_XHCI_PCI`
      (already `y`). X670E is built from two Promontory 21 dies and both chipset
      USB controllers are present here — `[1022:43f7]` at `13:00.0` and
      `15:00.0` — so this adds a chipset temperature the board does not
      otherwise expose to Linux.
- [ ] Drop `# CONFIG_ATALK is not set` from `base.config`. It is the only
      fragment symbol of the 87 removed in 7.2, so the driver is gone and the
      line becomes a no-op that the symbol check will flag.

The `optc401_disable_crtc` `REG_WAIT timeout` warning in the boot log is not
fixed in 7.2 — the only change to `dcn401_optc.c` is an HDMI 2.1 FRL out-mux
mapping, and both monitors here are DisplayPort. Cosmetic, no action.

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
