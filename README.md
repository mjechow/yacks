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

The Realtek RTL8125 NIC (r8169 driver) requires firmware files not yet
included in the `linux-firmware` package. Download and install manually:

```bash
wget https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtl_nic/rtl8125k-1.fw
wget https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/rtl_nic/rtl9151a-1.fw
sudo cp rtl8125k-1.fw rtl9151a-1.fw /lib/firmware/rtl_nic/
```

## Requirements

- GCC 13+ (required for `-march=znver4`)
- git
- ccache
- dpkg-deb (included in dpkg on Debian/Ubuntu)
- Kernel sources cloned into a `linux/` subdirectory (see Quick Start)

## Quick Start

Using an LTS kernel version is recommended for stability and longer support.
Currently tested against the `linux-rolling-lts` branch.

```bash
# Clone the kernel sources next to the scripts
git clone --branch linux-rolling-lts \
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

- **CPU tuning:** `-march=znver4 -mtune=znver4` via KCFLAGS
- **Preemption:** Full preempt with `PREEMPT_DYNAMIC` + 1000 Hz timer
- **Scheduler:** `SCHED_AUTOGROUP` (prevents `make -j32` from starving the desktop)
- **Memory:** THP with MADVISE, Multi-Gen LRU, PER_VMA_LOCK, NUMA balancing
- **Swap:** zswap with zstd compressor (default on)
- **Network:** BBR congestion control, FQ/FQ_CODEL/CAKE qdisc
- **I/O:** kernel default (`none`) for NVMe — no scheduler tuning needed
- **Modules:** zstd compression
- **Security:** AppArmor (Mint default), no SELinux
- **Debug:** All tracing, kprobes, BTF, DWARF, KASAN, etc. disabled

## Disabled Subsystems

To reduce build time and kernel footprint, the following are disabled:

| Category | Disabled |
| --- | --- |
| GPU drivers | Intel (i915, Xe), Nouveau, legacy AMD radeon |
| Wireless | WiFi stack, NFC, WiMAX, hamradio, CAN, ISDN |
| Legacy buses | PCMCIA, FireWire, InfiniBand, parallel port, floppy |
| Legacy storage | All PATA/IDE drivers; unused SATA add-in controllers (Promise, SIL, NV, VIA, ULI, MV…) |
| NICs | ~60 unused vendors; enterprise cards (Chelsio, Broadcom bnx2x); ~30 legacy USB network adapters |
| Storage HBAs | All SCSI HBA drivers (Fibre Channel, SAS, iSCSI); FCoE stack; Arcmsr, SYM53C8XX |
| Filesystems | XFS, ReiserFS, JFS, NILFS2, EROFS, OCFS2, GFS2, Ceph, OrangeFS, AFS, 9P, Coda, HFS/HFS+, Minix, ROMFS, CRAMFS, UFS |
| Protocols | IPX, AppleTalk, X.25, DECnet, ATM, TIPC, DCCP, RDS, SCTP, L2TP, WireGuard (VPN handled by Fritz!Box router) |
| Virtualisation | Xen and Hyper-V guest support, staging drivers |
| Media | TV tuners, DVB, radio, SDR, IR remote controls — UVC webcam kept |
| Input | Touchscreen, tablet/pen, game controllers (joystick, XInput, PlayStation, Steam), laptop touchpad drivers (ALPS, Elan, Synaptics, Cypress, TrackPoint, FocalTech) |
| Crypto HW | Non-AMD accelerators: Intel QAT, Marvell/Cavium NITROX+ZIP, VIA Padlock, Atmel secure elements |
| Platform | ChromeOS, Surface, Mellanox platform drivers; laptop PCIe card readers (Realtek, Alcor) |
| Industrial / embedded | IIO (sensors), MTD (flash), I3C, GNSS/GPS, CXL, DCA, Greybus, COMEDI, HSI |
| Accessibility | Braille console, Speakup screen reader |
| Sound | AMD APU audio (Raven, Renoir, Van Gogh, Yellow Carp, Phoenix, Rembrandt — 7950X3D has no iGPU); all unused HDA codecs; Intel SOC audio |
| Misc | Hardware watchdog, NTB, FPGA |

## Config Fragments

Kernel config customizations are split into composable fragments under
`fragments/`, merged by `scripts/kconfig/merge_config.sh`. Each fragment groups
related options so only the relevant files need to change when hardware changes.

| Fragment | Contents |
| --- | --- |
| `base.config` | Compiler/LTO, zstd, zswap, scheduling, preemption, timer, security, debug, module signing |
| `cpu-amd-zen4.config` | Ryzen 9 7950X3D: P-state, EDAC, SMBus, AES-NI, ACPI, PCIe, hardware monitoring |
| `gpu-amd.config` | RX 9070 (RDNA 4): enables amdgpu + ROCm/HSA |
| `sound-realtek.config` | HDA Intel + Realtek ALC4080 (3.5mm) + USB audio; disables unused HDA codecs, AMD APU audio, Intel SOC audio |
| `sound-hdmi.config` | HDMI/DP audio codecs for AMD (ATI); comment out to disable all display audio |
| `network-realtek.config` | RTL8125 2.5GbE, Bluetooth; disables WiFi, all other NIC vendors, legacy USB network adapters; BBR/FQ/Cake |
| `storage.config` | NVMe, SATA, SCSI, filesystems; disables PATA, unused SATA controllers, exotic FS, enterprise HBA/FCoE |
| `hardware-desktop.config` | USB, HID, SD card readers, UVC webcam, watchdog off, no-AMD crypto accelerators; disables laptop touchpad drivers and PCIe card readers |

Fragments are applied in the order listed; later fragments take precedence on
conflicts. `merge_config.sh` runs `make olddefconfig` after the merge, so
Kconfig `select` and `depends` chains are always resolved correctly.

## Project Structure

```text
buildKernel.sh       Main build orchestrator
fragments/           Composable Kconfig fragments (merged by merge_config.sh)
linux/               Kernel source tree (cloned separately, not tracked)
ccache_kernel/       Dedicated ccache directory (generated)
```

## Linting

CI runs [pre-commit](https://pre-commit.com) on push to `main` and on PRs.
The same hooks run locally before each commit:

```bash
# Install pre-commit hooks (one-time setup)
pip install pre-commit
pre-commit install

# Run all hooks manually
pre-commit run --all-files
```

**shfmt style:** 2-space indent (`-i 2`), case indent (`-ci`), space after
redirect (`-sr`), keep column alignment (`-kp`).

## Kernel Config Gotchas

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

## Roadmap

No open items.
