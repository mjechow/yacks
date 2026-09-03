# YACKS

**Yet Another Compile Kernel Script** — a custom Linux kernel build system for
Ubuntu / Linux Mint desktops.

YACKS downloads the Ubuntu mainline kernel config from
<https://kernel.ubuntu.com/~kernel-ppa/mainline/>, applies hardware-specific
optimizations, disables all debug/tracing overhead, and compiles the kernel into
installable `.deb` packages.

## What It Does

1. Checks whether the kernel source tree is up to date with its upstream remote
   (`git ls-remote` comparison, no fetch required); warns if behind.
   The kernel version is read directly from `linux/Makefile` (no tags required).
2. Fetches the matching Ubuntu mainline `.deb` and extracts its `.config`
   (falls back to the running kernel config if the download fails)
3. Merges hardware-specific config fragments from `fragments/` using
   `scripts/kconfig/merge_config.sh` for proper Kconfig dependency resolution
   (see [Target Hardware](#target-hardware) and [Config Fragments](#config-fragments))
4. Builds the kernel with `make bindeb-pkg`, producing `linux-image`,
   `linux-headers`, and `linux-libc-dev` packages, then prompts to install them

## Who Is It For

Anyone running Linux Mint or Ubuntu on AMD Zen 4 hardware who wants a
stripped-down, performance-tuned kernel without distro debug overhead. The
config is opinionated — it disables WiFi, Intel/NVIDIA GPU drivers, game
controllers, and dozens of unused subsystems to reduce build time and kernel
size.

## Target Hardware

AMD Zen 4 (Ryzen 9 7950X3D), AMD GPU (RX 9070), Linux Mint 22.3.
See `fragments/cpu-amd-zen4.config` and `fragments/hardware-desktop.config` for
the full hardware profile.

## Firmware

No manual firmware installation is needed. The onboard NIC identifies as
`RTL8125B, XID 641` and requests `rtl_nic/rtl8125b-2.fw`, which ships in the
`linux-firmware` package.

Every `update-initramfs` run nevertheless prints:

```text
W: Possible missing firmware /lib/firmware/rtl_nic/rtl8125cp-1.fw for built-in driver r8169
```

This is expected and needs no action. `r8169` declares 29 firmware files via
`MODULE_FIRMWARE` — one per supported chip — and because `CONFIG_R8169=y` builds
it in, `initramfs-tools` cannot resolve them as module dependencies and warns
about every file it does not find. `rtl8125cp-1.fw` belongs to the RTL8125CP,
a different chip; fetching it manually would be as pointless as it was for
`rtl8125k-1.fw`, because this card never requests it. Before treating any such
warning as a real gap, check the XID the driver reports:

```bash
dmesg | grep r8169          # look for "RTL8125B, ..., XID 641"
```

## Requirements

- GCC 13+ (required for `-march=znver4`)
- git
- ccache
- dpkg-deb (included in dpkg on Debian/Ubuntu)
- Kernel sources cloned into a `linux/` subdirectory (see Quick Start)

## Quick Start

Currently tested against the `linux-rolling-stable` branch, which always tracks
the newest stable series. Use `linux-rolling-lts` instead if you prefer longer
support over newer features — the build itself works with either.

```bash
# Clone the kernel sources next to the scripts
git clone --branch linux-rolling-stable \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

cd ..

# Build (prompts to install at the end)
./buildKernel.sh
```

## Configuration

Edit variables at the top of `buildKernel.sh` before running:

| Variable    | Default        | Description                                              |
| ----------- | -------------- | -------------------------------------------------------- |
| `DEBUG`     | `0`            | Set to `1` for debug output (also enables VERBOSITY)     |
| `VERBOSITY` | `0`            | Set to `1` for verbose `make` output                     |
| `REV`       | _(empty)_      | Optional revision suffix (e.g. `REV=2` → `user-host-2`)  |
| `N_PROC`    | `$(nproc) + 2` | Parallel make jobs (max 1.5x cores for I/O-bound builds) |

The build uses a **separate ccache directory** (`ccache_kernel/`, 10 GB max) to
avoid interfering with your regular ccache.

Additional commands:

```bash
./buildKernel.sh -h            # show help (--help)
./buildKernel.sh -l            # list all installed kernels, marks the running one (--list)
./buildKernel.sh -c            # clean build artifacts, archive debs to old/ (--clean)
./buildKernel.sh -p            # remove old installed kernels, keeps newest 2 + distro (--purge-old)
./buildKernel.sh -t            # build and install cpupower, one-time, requires sudo (--tools)
```

## Key Optimizations

- **CPU tuning:** `-march=znver4 -mtune=znver4` via KCFLAGS. The Kconfig x86-64
  processor family choice was removed in 6.15, so KCFLAGS is the only remaining
  route; `X86_NATIVE_CPU` is deliberately off because it hardcodes
  `-march=native` on the build host.
- **CPU frequency:** `amd_pstate` in active mode — the driver registers as
  `amd-pstate-epp` and the firmware picks frequencies via the
  `energy_performance_preference`, so the compiled-in schedutil default only
  applies if the mode is switched to passive/guided.
- **Preemption:** Full preempt with `PREEMPT_DYNAMIC` + 1000 Hz timer
- **Scheduler:** `SCHED_AUTOGROUP` (prevents `make -j32` from starving the
  desktop); `SCHED_CACHE` off, see decisions
- **Memory:** THP with ALWAYS, Multi-Gen LRU, PER_VMA_LOCK
- **Wine/Proton:** `NTSYNC` built in, so `/dev/ntsync` always exists — as a
  module nothing autoloads it and Wine silently falls back to esync/fsync
- **Swap:** zswap with zstd compressor (default on)
- **Network:** BBR congestion control, FQ/FQ_CODEL/CAKE qdisc
- **I/O:** kernel default (`none`) for NVMe — no scheduler tuning needed
- **Modules:** zstd compression
- **Security:** AppArmor (Mint default), no SELinux
- **Debug:** All tracing, kprobes, BTF, DWARF, KASAN, etc. disabled

## Disabled Subsystems

To reduce build time and kernel footprint, the following are disabled:

<!-- pyml disable line-length -->
| Category | Disabled |
| --- | --- |
| GPU drivers | Intel (i915, Xe), Nouveau, legacy AMD radeon |
| Wireless | WiFi stack, NFC, WiMAX, hamradio, CAN, ISDN |
| Legacy buses | PCMCIA, FireWire, InfiniBand, parallel port, floppy |
| Legacy storage | All PATA/IDE drivers; unused SATA add-in controllers (Promise, SIL, NV, VIA, ULI, MV…) |
| NICs | ~60 unused vendors; enterprise cards (Chelsio, Broadcom bnx2x); ~30 legacy USB network adapters |
| Storage HBAs | All SCSI HBA drivers (Fibre Channel, SAS, iSCSI); FCoE stack; Arcmsr, SYM53C8XX |
| Filesystems | XFS, ReiserFS, JFS, NILFS2, EROFS, OCFS2, GFS2, Ceph, OrangeFS, AFS, 9P, Coda, HFS/HFS+, Minix, ROMFS, CRAMFS, UFS |
| Protocols | IPX, X.25, DECnet, ATM, TIPC, DCCP, RDS, SCTP, L2TP, WireGuard (VPN handled by Fritz!Box router) |
| Virtualisation | Xen and Hyper-V guest support, staging drivers |
| Media | TV tuners, DVB, radio, SDR, IR remote controls — UVC webcam kept |
| Input | Touchscreen, tablet/pen, the whole joystick/gamepad subsystem (`INPUT_JOYSTICK`, joydev, XInput) and the HID gamepad drivers (PlayStation, Steam, Sony, Nintendo, Microsoft, Thrustmaster, Saitek, …) plus Logitech force-feedback; laptop touchpad drivers (ALPS, Elan, Synaptics, Cypress, TrackPoint, FocalTech). `HID_LOGITECH` itself stays enabled — `HID_LOGITECH_DJ` (Logi Bolt receiver) depends on it |
| Crypto HW | Non-AMD accelerators: Intel QAT, Marvell/Cavium NITROX+ZIP, VIA Padlock, Atmel secure elements |
| Platform | ChromeOS, Surface, Mellanox platform drivers; laptop PCIe card readers (Realtek, Alcor) |
| Industrial / embedded | IIO (sensors), MTD (flash), I3C, GNSS/GPS, CXL, DCA, Greybus, COMEDI, HSI |
| Accessibility | Braille console, Speakup screen reader |
| Sound | The whole HDA stack and all of ASoC (`SND_SOC`) — every audio device here is USB, so HDMI/DP display audio, Intel SOF/AVS and AMD ACP all go with one symbol. Drops sound modules from 629 to 105 |
| Storage | MMC/SD stack — the card readers are USB mass storage |
| Misc | Hardware watchdog, NTB, FPGA |
<!-- pyml enable line-length -->

## Config Fragments

Kernel config customizations are split into composable fragments under
`fragments/`, merged by `scripts/kconfig/merge_config.sh`. Each fragment groups
related options so only the relevant files need to change when hardware changes.

<!-- pyml disable line-length -->
| Fragment | Contents |
| --- | --- |
| `base.config` | Compiler/LTO, zstd, zswap, scheduling, preemption, timer, security, debug, module signing |
| `cpu-amd-zen4.config` | Ryzen 9 7950X3D: P-state, EDAC, SMBus, AES-NI, ACPI, PCIe, hardware monitoring |
| `gpu-amd.config` | RX 9070 (RDNA 4): enables amdgpu + ROCm/HSA |
| `sound-usb.config` | The audio actually in use: USB only — the ALC4080 is wired to an internal USB port on X670E, not to the HDA bus |
| `sound-hdmi.config` | Display and APU audio switched off, for both GPUs; also the iGPU's entire kernel-config surface. Swap the negatives to re-enable HDMI/DP sound |
| `network-realtek.config` | RTL8125 2.5GbE, Bluetooth; disables WiFi, all other NIC vendors, Fujitsu Extended Socket, legacy USB network adapters; BBR/FQ/Cake |
| `storage.config` | NVMe, SATA, SCSI, filesystems; disables PATA, unused SATA controllers, exotic FS, enterprise HBA/FCoE |
| `hardware-desktop.config` | USB, HID, SD card readers, UVC webcam, watchdog off, no-AMD crypto accelerators; disables laptop touchpad drivers, PCIe card readers, Fujitsu laptop/tablet platform drivers |
<!-- pyml enable line-length -->

Fragments are applied in the order listed; later fragments take precedence on
conflicts. `merge_config.sh` runs `make olddefconfig` after the merge, so
Kconfig `select` and `depends` chains are always resolved correctly.

## Project Structure

```text
buildKernel.sh       Main build orchestrator
fragments/           Composable Kconfig fragments (merged by merge_config.sh)
tools/               knobbench + measure.sh (runtime knob comparison)
linux/               Kernel source tree (cloned separately, not tracked)
ccache_kernel/       Dedicated ccache directory (generated)
```

## Measuring Runtime Knobs

`tools/` holds a small benchmark for the knobs that are switchable without a
rebuild — preemption model, cpuidle governor, THP mode and `SCHED_CACHE` LLC
aggregation — so a config change can be decided on numbers instead of
reputation. It needs no external dependencies.

```bash
make -C tools                  # build as your normal user
sudo ./tools/measure.sh        # sysfs writes need root; state is restored on exit
```

`knobbench` can also be run alone for a single sub-benchmark: `pingpong`
(wakeup latency under load), `idlewake` (timer wakeup from a deep C-state),
`tlb` (random access over a 1 GiB working set) or `spread` (eight threads
hammering one shared 24 MiB buffer). See the decisions section for what the
current settings were chosen on.

`pingpong`, `idlewake` and `tlb` pin to CCD0 (the 96 MB L3 chiplet) for
reproducibility. `spread` deliberately does not: `SCHED_CACHE` aggregates the
threads of one process onto a single LLC, so it only shows up when the balancer
is free to place them. The buffer fits in either CCD's L3, which makes
co-location worth something, and the run reports the share of CPU samples that
landed on the busiest LLC — so a throughput number always comes with the
placement that produced it.

### Reference run

Plain `tools/knobbench`, no arguments, on the running defaults — `preempt=full`,
cpuidle governor `menu`, THP `always`. Kept as the comparison point for the next
version bump.

| sub-benchmark | unit | p50 | p90 | p99 | p999 | max |
| --- | --- | --- | --- | --- | --- | --- |
| `pingpong` | µs | 4.92 | 5.01 | 6.31 | 2439 | 2812 |
| `idlewake` | µs | 83.3 | 339.7 | 369.7 | 526.9 | 629.9 |
| `tlb` | ns/access | 77.44 | — | — | — | — |
| `spread` | M ops/s | 1617 | — | — | — | — |

Kernel `7.2.3-mirko-mars-3`. `pingpong` is the median of five runs, p50 spread
4.91–4.93 µs, and `spread` the median of five, 1599–1624 M ops/s with 99-100% of
CPU samples on one LLC every time; `idlewake` and `tlb` are one run each. `tlb`
ran 50.0 M chase steps with `AnonHugePages` at 1 GiB — the whole working set went
huge.

`spread` only belongs in a baseline table because `SCHED_CACHE` is off. With it
compiled in, throughput tracks whichever LLC the aggregation picked that run, and
a single number means nothing without the placement share beside it.

## Linting

CI runs [pre-commit](https://pre-commit.com) on every pull request against
`main`. The same hooks run locally before each commit:

```bash
# Install pre-commit hooks (one-time setup)
pip install pre-commit
pre-commit install

# Run all hooks manually
pre-commit run --all-files
```

**shfmt style:** 2-space indent (`-i 2`), case indent (`-ci`), space after
redirect (`-sr`), keep column alignment (`-kp`).

**C code:** no linter, but the `build-knobbench` hook compiles `tools/` with
`-Wall -Wextra` whenever `knobbench.c` or its `Makefile` changes, locally and in
CI. A compile catches more in a file this size than `clang-tidy` would.

## Kernel Config Gotchas

- Before merging, `buildKernel.sh` checks every fragment symbol against the
  `Kconfig` tree and warns about names that do not exist in this kernel version.
  Such entries are silent no-ops: `merge_config.sh -m -Q` does not report them,
  and the diff check below cannot see them either because no transition ever
  happens. Symbols get renamed (`USB_ASIX` → `USB_NET_AX8817X`) or removed
  (`GENERIC_CPU`, `X86_64_V3` dropped in 6.15) on version bumps, so treat every
  entry in this warning as a broken intent, not as harmless legacy.
- `merge_config.sh` warns on conflicts (later fragment wins) and on fragment
  values that did not make it into the final `.config` (missing dependencies or
  removed symbols). After a kernel version bump, watch for these warnings and
  also check the generated `.diff` file to catch renamed or removed options.
- Options set in a fragment that are overridden by a Kconfig `select` in a
  later `olddefconfig` pass will appear in the diff as reverted — this is
  expected; move conflicting options to the fragment that enables their parent.
- Before each build, `buildKernel.sh` scans the generated `.diff` for any
  transition involving `n` (`n -> y`, `n -> m`, `y -> n`, `m -> n`) and warns
  if any are found. These indicate a fragment value was overridden by
  `olddefconfig`, typically because a `select` dependency pulled something back
  in. To fix: find the selecting parent with
  `grep -rn "select CONFIG_FOO" linux/ --include="Kconfig"`, then disable
  that parent in the appropriate fragment. Note: `scripts/config` silently
  ignores unknown symbol names — always verify the exact symbol in the Kconfig
  tree, not just the driver name.

## Decisions

- **Secure Boot / MOK enrollment:** not used. Stationary desktop, no disk
  encryption, no threat model that Secure Boot addresses.
- **Module signing:** `MODULE_SIG_ALL=y`. With `MODULE_SIG=y` but nothing signed,
  every module load sets `TAINT_UNSIGNED_MODULE`. The key is generated per build
  and its public half lands in the matching vmlinux, so it does not need to
  survive the `git clean -dfx` in `reset_kernel_src`. This also keeps
  `module.sig_enforce=1` available as a cmdline-only hardening step.
- **3D V-Cache mode:** left at the `frequency` default. `cache` mode parks the
  non-V-Cache CCD and suits games better, but this machine games less than 10 %
  of the time. Switching is a runtime concern
  (`/sys/bus/platform/drivers/amd_x3d_vcache/*/amd_x3d_mode`), not a kernel
  config one.
- **Debug and tracing options:** off, but for build time and image size, not as a
  matter of principle — anything without a runtime cost is fair game when there
  is a use for it. Two findings worth keeping: `FUNCTION_TRACER` is the option
  that costs (an `__fentry__` call per function); `FTRACE=y` with
  `FUNCTION_TRACER=n` still yields `TRACING`, `TRACEPOINTS`, `EVENT_TRACING`,
  `BPF_EVENTS` and the `osnoise`/`timerlat` latency tracers at NOP-patched cost.
  DWARF carries no runtime cost at all — its debug sections are never loaded.
- **`SCHED_CLASS_EXT` (sched\_ext):** off, because the userspace half is missing.
  Mint 22.3 packages no `scx` schedulers, and without one the kernel keeps using
  EEVDF, so enabling it changes nothing on its own. It also pulls in a hard
  dependency chain — `SCHED_CLASS_EXT` needs `DEBUG_INFO_BTF`, which needs DWARF;
  `olddefconfig` silently drops both if `DEBUG_INFO_NONE` stays set. Revisit if
  `scx_lavd` is ever built from source.
- **Display audio (HDMI/DP): off, and with it the entire HDA stack.** Sound over
  the monitor is not wanted here; every audio device on this machine is USB. The
  discrete GPU's HDMI/DP codec was the only HDA codec present, so once display
  audio goes there is nothing left for HDA to drive. Removing it needs more than
  `SND_HDA_INTEL=n` — `SND_HDA_ACPI` and, on an AMD box of all things,
  `SND_SOC_INTEL_AVS` (via `SND_SOC_HDA`) both select the hidden `SND_HDA` core
  back in. Disabling `SND_SOC` at the root settles it and takes Intel SOF/AVS and
  AMD ACP with it: sound modules drop from 629 to 105.
  Consequences, in case sound ever goes missing: nothing can play over
  DisplayPort or HDMI, and enabling the Raphael iGPU for display output would
  need `SND_HDA_INTEL` back. All of it sits in `fragments/sound-hdmi.config`,
  which stays registered in `FRAGMENT_FILES` so the symbols keep being validated
  on every build — a fragment left out of that array is checked by nothing and
  rots unnoticed until the day it is needed.
- **Game controllers:** disabled consistently rather than half-enabled. A
  controller attached later needs a kernel rebuild.
- **Promontory 21 chipset temperature (`SENSORS_PROM21_XHCI`, new in 7.2):** off,
  because it cannot bind here. The hwmon driver sits on an auxiliary device that
  `xhci-pci` creates only for `[1022:43fc]` and `[1022:43fd]`; both chipset xHCI
  functions on this X670E are `[1022:43f7]`. Leaving it off also drops the
  `USB_XHCI_PCI_PROM21` glue, which is built in by default whenever the sensor is
  enabled.
- **`PREEMPT_LAZY`:** rejected on measurement. `preempt=lazy` is switchable at
  runtime regardless of this symbol — `sched_dynamic_mode()` gates it on
  `ARCH_HAS_PREEMPT_LAZY`, which x86 selects — so it was compared directly
  against `full`. Wakeup round-trip for a latency-sensitive thread sharing a
  core with a CPU-bound one: p50 5.15 us on `full` versus 1.00 ms on `lazy`,
  exactly one tick at `HZ=1000`, which is the designed behaviour — the wakeup
  waits for the next tick instead of preempting. The test is adversarial by
  construction, but `lazy` showed no upside anywhere, so `full` stays.
  Note that on x86 `sched_dynamic_mode()` accepts only `full` and `lazy`;
  `none` and `voluntary` are compiled out when the arch supports lazy.
- **`SCHED_CACHE` (new in 7.2):** off, on measurement. It aggregates the threads
  of one process onto a single LLC, which on paper suits the asymmetric L3 here
  (96 MB on CPUs 0-7,16-23, 32 MB on 8-15,24-31). In practice it cannot tell the
  two apart: the working-set figure it compares against LLC capacity,
  `mm->sc_stat.footprint`, is only ever raised from `task_numa_fault()`, and this
  is a single-node box with `numa_balancing=0`, so it stays zero. Eight threads
  sharing a 24 MiB buffer, ten runs a side: with the mechanism off the ordinary
  balancer put them on the higher-clocking CCD every time, 1621 M ops/s with a
  0.6% spread; with it on, five of ten runs were dragged onto the V-Cache CCD or
  split across both, at 956-1406 M ops/s. It also costs ~220 ns per context
  switch in `account_mm_sched()`, which `pingpong` sees as p50 5.15 us against
  4.93 us. Switchable at runtime via
  `/sys/kernel/debug/sched/llc_balancing/enabled` when compiled in — but there is
  no Kconfig or cmdline for the default, so off in the config is the only way to
  get it without a boot-time write.
- **`TRANSPARENT_HUGEPAGE_ALWAYS`:** chosen on measurement, 91.2 -> 77.6 ns per
  random access over a 1 GiB working set (-15%), reproducible across runs, with
  `AnonHugePages` confirming the mapping went huge only under `always`.
- **cpuidle governor:** `menu` and `teo` are both compiled in and there is no
  Kconfig for the default — selection is by `.rating` (menu 20 beats teo 19), so
  `menu` wins unless `cpuidle.governor=` says otherwise. Measured timer wakeup
  from a deep C-state: `teo` held a p50 of 86-96 us across runs while `menu`
  scattered between 86 and 341 us; p90/p99 were comparable. The kernel config is
  deliberately left alone so the governor stays switchable at runtime.

## Roadmap

Open items live in [todo.md](todo.md): the remaining kernel hardening gaps, and
the measurements to redo now that the tree is on 7.2.
