#!/usr/bin/env bash

# ==============================================================================
# buildKernel.sh – YACKS (yet another compile kernel script)
# ==============================================================================

set -euo pipefail

# optional build revision suffix; if set, appended to LOCALVERSION as -$REV (e.g. REV=2 → username-hostname-2)
# use a date (e.g. 20250524) or incrementing number so dpkg sorts newer builds higher than older ones
REV= # $(date +%Y%m%d)
DEBUG=0
VERBOSITY=$DEBUG

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

FRAGMENTS_DIR="${SCRIPT_DIR}/fragments"
PATCHES_DIR="${SCRIPT_DIR}/patches"
KERNEL_SRC_DIR="linux"
BUILD_LOG_FILE="kernelBuild.log"
LOCALVERSION="$(whoami)-$(hostname -s)${REV:+-$REV}"

ARCH="$(uname -m)"
export ARCH
export CCACHE_DIR="${SCRIPT_DIR}/ccache_kernel" # separate from the regular ccache
export CCACHE_MAXSIZE="10G"
KBUILD_BUILD_TIMESTAMP="$(git -C "${SCRIPT_DIR}/${KERNEL_SRC_DIR}" log -1 --format='%cd' --date=format:'%a %b %d %T %Z %Y')"
export KBUILD_BUILD_TIMESTAMP
export LD=ld.bfd
# shfmt-ignore
export N_PROC=$(($(nproc) + 2)) # default: +2; you should configure a maximum of 1.5x CPU cores for faster builds on I/O bound systems

# --- Helpers -----------------------------------------------------------------
info() { printf "[*] %s\n" "$@"; }
warn() { printf "[!] %s\n" "$@"; }
debug() {
  [[ $DEBUG -eq 0 ]] && return 0
  printf "[D] %s\n" "$@"
}
success() { printf "[+] %s\n" "$@"; }
die() {
  printf "ERROR: %s\n" "$@" >&2
  exit 1
}
reset_kernel_src() {
  git -C "$SCRIPT_DIR/$KERNEL_SRC_DIR" reset --hard > /dev/null
  git -C "$SCRIPT_DIR/$KERNEL_SRC_DIR" clean -dfx   > /dev/null
}
# Patches live in patches/, outside the kernel tree, so the reset above cannot
# touch them; they are re-applied before every build. git apply leaves no commits,
# which keeps the upstream-freshness check comparing like with like.
apply_patches() {
  local p name err subject date hash patches=("$PATCHES_DIR"/*.patch)
  [[ -e ${patches[0]} ]] || return 0 # unmatched glob stays literal

  info "Applying ${#patches[@]} patch(es) from patches/..."
  for p in "${patches[@]}"; do # cwd is the kernel tree by now, as for the make calls below
    name=${p##*/}
    if err=$(git apply "$p" 2>&1); then # atomic: nothing is applied unless all of it applies
      success "  $name"
    elif git apply --reverse --check "$p" 2> /dev/null; then
      [[ -z $(git rev-list '@{u}..HEAD') ]] || die "$name is in a local commit of the kernel tree, not upstream — keep it"
      die "$name is already in the kernel tree — it landed upstream, delete it"
    else
      # An upstream commit with the same subject means it most likely landed edited
      subject=$(sed -n 's/^Subject: \(\[[^]]*\] \)\{0,1\}//p' "$p")
      date=$(sed -n 's/^Date: //p' "$p")
      hash=$(git log -1 --format=%h --since="$date" -F --grep="$subject")
      [[ -z $hash ]] || die "$name does not apply, but commit $hash has its subject — check whether it landed upstream in edited form"
      die "$name does not apply to this kernel version: $err"
    fi
  done
}
usage() {
  printf "Yet Another Compile Kernel Script — a custom Linux kernel build system for\n"
  _ver=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || true)
  printf "Ubuntu / Linux Mint desktops.%s\n\n" "${_ver:+ Version $_ver}"
  printf "Usage: %s [OPTION]\n\n" "$(basename "$0")"
  printf "  -c, --clean      Archive debs to old/, reset kernel source\n"
  printf "  -l, --list       List all installed kernels\n"
  printf "  -p, --purge-old  Remove old installed kernels (keeps newest 2 + distro)\n"
  printf "  -t, --tools      Build and install cpupower (requires sudo)\n"
  printf "  -h, --help       Show this help\n"
  printf "\n  (no option)    Full kernel build\n"
}

case "${1:-}" in
  -c) set -- "--clean" ;;
  -l) set -- "--list" ;;
  -p) set -- "--purge-old" ;;
  -t) set -- "--tools" ;;
  -h) set -- "--help" ;;
  --clean | --list | --purge-old | --tools | --help) ;;
  --* | -* | ?*) printf "ERROR: Unknown option: %s\n\n" "${1}" >&2; usage >&2; exit 1 ;;
esac

# --- Help --------------------------------------------------------------------
if [[ "${1:-}" == "--help" ]]; then
  usage; exit 0
fi

# --- List installed kernels --------------------------------------------------
if [[ "${1:-}" == "--list" ]]; then
  running="$(uname -r)"
  { dpkg -l "linux-image-*" 2>/dev/null || true; } | awk '/^ii/{print $2}' | sort -V | while IFS= read -r pkg; do
    ver="${pkg#linux-image-}"
    if [[ "$ver" == "$running" ]]; then
      printf "  %s  (running)\n" "$pkg"
    else
      printf "  %s\n" "$pkg"
    fi
  done
  exit 0
fi

# --- Clean mode --------------------------------------------------------------
if [[ "${1:-}" == "--clean" ]]; then
  cd "$SCRIPT_DIR"
  mkdir -p old
  rm -f ./*.log ./*.buildinfo ./*.changes ./linux-modules-*.deb

  # Archive each artifact type, then keep only its most recent files: 3 debs per
  # package, 4 configs (one build's base, .pre, .diff and final)
  # shellcheck disable=SC2012,SC2086  # filenames are controlled; $pat must glob
  for pat in "linux-image-*.deb" "linux-headers-*.deb" "linux-libc-dev_*.deb" "config-*"; do
    keep=3
    [[ $pat == config-* ]] && keep=4
    mv -f ./$pat old/ 2> /dev/null || true
    ls -t old/$pat 2> /dev/null | tail -n +$((keep + 1)) | xargs -r rm -f || true
  done

  reset_kernel_src
  success "Clean complete. Archived to old/ (last 3 debs per package, configs of the latest build), kernel source reset."
  exit 0
fi

# --- Purge old kernels -------------------------------------------------------
if [[ "${1:-}" == "--purge-old" ]]; then
  lb="$(whoami)-$(hostname -s)"
  { dpkg -l "linux-image-*-${lb}*" 2>/dev/null || true; } | awk '/^ii/{print $2}' | sort -V | head -n -2 \
    | sed -n 'p;s/linux-image-/linux-headers-/p' | xargs -r sudo apt-get purge -y
  sudo apt-get autoremove -y && success "Done."; exit 0
fi

# --- Tools mode: build and install cpupower from kernel source ---------------
if [[ "${1:-}" == "--tools" ]]; then
  cd "$SCRIPT_DIR/$KERNEL_SRC_DIR"
  make -j"$N_PROC" -C tools/power/cpupower
  sudo make -C tools/power/cpupower install
  sudo ldconfig
  success "cpupower installed."
  exit 0
fi

# --- Sanity checks -----------------------------------------------------------
info "Current kernel: $(uname -r)"
debug "Script directory: $SCRIPT_DIR"
cd "$SCRIPT_DIR/$KERNEL_SRC_DIR" 2> /dev/null ||
  die "Kernel source directory '$KERNEL_SRC_DIR' not found. Did you clone the kernel sources?"

# --- Verify GCC --------------------------------------------------------------
if ! command -v gcc &> /dev/null; then
  die "GCC not found."
fi
GCC_MAJOR=$(gcc -dumpversion | cut -d. -f1)
info "Using GCC ${GCC_MAJOR}"
[[ "$GCC_MAJOR" -lt 13 ]] && die "GCC 13+ required for znver4, found GCC ${GCC_MAJOR}"

command -v ccache &> /dev/null || die "ccache not found."

# --- Check if kernel source is up to date ------------------------------------
_upstream_hash=$(timeout 5 git ls-remote origin "refs/heads/$(git rev-parse --abbrev-ref HEAD)" 2> /dev/null | awk '{print $1}' || true)
if [[ -n "$_upstream_hash" && "$(git rev-parse HEAD)" != "$_upstream_hash" ]]; then
  warn "Kernel source is not at the latest upstream commit."
fi
unset _upstream_hash

# --- Clean & reset git -------------------------------------------------------
info "Cleanup and checkout..."
reset_kernel_src
apply_patches

# --- Determine kernel version from Makefile -----------------------------------
KERNEL_VERSION_DIR=v$(awk '/^VERSION =/{v=$3} /^PATCHLEVEL =/{p=$3} /^SUBLEVEL =/{s=$3} END{print v"."p"."s}' Makefile)
[[ "$KERNEL_VERSION_DIR" == "v.." ]] && die "Could not parse kernel version from Makefile."
debug "Kernel version from Makefile: $KERNEL_VERSION_DIR"
KERNEL_VERSION="${KERNEL_VERSION_DIR#v}" # strip leading 'v'; only adds hyphen if REV is set

# --- Download Ubuntu mainline .deb to extract its .config --------------------
UBUNTU_BASE_URL="https://kernel.ubuntu.com/~kernel-ppa/mainline/${KERNEL_VERSION_DIR}"
debug "Ubuntu mainline URL: $UBUNTU_BASE_URL"
# Ubuntu encodes version as zero-padded 6-digit string: 6.12.3 -> 061203
KERNEL_VERSION_LONG=$(echo "$KERNEL_VERSION" | awk -F. '{printf "%02d%02d%02d", $1, $2, $3}')
DEB_FILENAME="linux-modules-${KERNEL_VERSION}-${KERNEL_VERSION_LONG}-generic_${KERNEL_VERSION}-${KERNEL_VERSION_LONG}"

# Find the exact .deb name (timestamp suffix varies)
DEB_FILE=$(curl --connect-timeout 10 --max-time 30 -sL "$UBUNTU_BASE_URL" |
  grep -Eo "${DEB_FILENAME}.[0-9]{12}_amd64.deb" |
  head -1) || true
[[ -n "$DEB_FILE" ]] || warn "Could not find .deb for kernel ${KERNEL_VERSION} at ${UBUNTU_BASE_URL}"

DEB_URL="${UBUNTU_BASE_URL}/amd64/${DEB_FILE}"
debug "Ubuntu .deb URL: $DEB_URL"
DEB_CACHE="$SCRIPT_DIR/${DEB_FILE}"
CONFIG_INSIDE_DEB="./boot/config-${KERNEL_VERSION}-${KERNEL_VERSION_LONG}-generic"

extract_ubuntu_config() {
  info "Extracting .config from ${DEB_FILE}..."
  dpkg-deb --fsys-tarfile "$DEB_CACHE" |
    tar xOf - "$CONFIG_INSIDE_DEB" > .config || die "Failed to extract config from deb"
  success "Config extracted."
}

fetch_ubuntu_config() {
  if [[ -f "$DEB_CACHE" ]]; then
    extract_ubuntu_config
  else
    info "Downloading kernel ${KERNEL_VERSION} config from Ubuntu mainline..."
    if [[ -n "$DEB_FILE" ]] && curl --connect-timeout 10 --max-time 600 -L --progress-bar -o "$DEB_CACHE" "$DEB_URL"; then
      success "Download complete."
      extract_ubuntu_config
    else
      warn "Download failed ($DEB_URL). Falling back to running kernel config."
      cp /boot/config-"$(uname -r)" .config || die "Failed to copy running kernel config"
    fi
  fi
  # Keep a copy of the base config before customization
  cp .config "$SCRIPT_DIR/config-$KERNEL_VERSION" || warn "Failed to save base config copy"
}

# --- Generate base config ----------------------------------------------------
info "Generating base kernel config..."
fetch_ubuntu_config

info "Expanding config defaults..."
make CC=gcc olddefconfig || die "Configuration processing failed!"

FRAGMENT_FILES=(
  "${FRAGMENTS_DIR}/base.config"
  "${FRAGMENTS_DIR}/cpu-amd-zen4.config"
  "${FRAGMENTS_DIR}/gpu-amd.config"
  "${FRAGMENTS_DIR}/sound-usb.config"
  "${FRAGMENTS_DIR}/sound-hdmi.config"
  "${FRAGMENTS_DIR}/network-realtek.config"
  "${FRAGMENTS_DIR}/storage.config"
  "${FRAGMENTS_DIR}/hardware-desktop.config"
  "${FRAGMENTS_DIR}/hardening.config"
)

info "Checking fragment symbols against the Kconfig tree..."
# merge_config.sh -m -Q stays silent about symbols that do not exist in this
# kernel version, and the diff check below never sees them either because no
# transition happens. Such entries are silent no-ops — catch them here.
_frag_syms=$(mktemp) _kconf_syms=$(mktemp)
grep -hoE 'CONFIG_[A-Z0-9_]+' "${FRAGMENT_FILES[@]}" | sort -u > "$_frag_syms"
git ls-files -z 'Kconfig' '*/Kconfig' 'Kconfig.*' '*/Kconfig.*' |
  xargs -0 grep -hoE '^[[:space:]]*(menu)?config[[:space:]]+[A-Z0-9_]+' |
  awk '{print "CONFIG_"$NF}' | sort -u > "$_kconf_syms"
UNKNOWN_SYMS=$(comm -23 "$_frag_syms" "$_kconf_syms")
rm -f "$_frag_syms" "$_kconf_syms"

info "Merging config fragments..."
# -m = merge only; we run olddefconfig ourselves afterward.
# Without -m, merge_config.sh runs alldefconfig and validates every value in the
# merged file (Ubuntu base + fragments), producing thousands of irrelevant
# warnings for options that don't exist in this kernel version.
scripts/kconfig/merge_config.sh -m -Q .config "${FRAGMENT_FILES[@]}" \
  || die "Config fragment merge failed!"

CONFIG_FILE="$SCRIPT_DIR/config-$KERNEL_VERSION-$LOCALVERSION"
DIFF_FILE="$CONFIG_FILE.diff"

info "Resolving Kconfig dependencies..."
cp .config "$CONFIG_FILE.pre"
make CC=gcc olddefconfig || die "Configuration processing failed!"
success "Fragments merged."
echo

info "Diffing: changes made by olddefconfig..."
./scripts/diffconfig "$CONFIG_FILE.pre" .config > "$DIFF_FILE" || die "Diffing configs failed!"
cp .config "$CONFIG_FILE"
success "Done."
echo

# --- Summary & confirmation --------------------------------------------------
git --no-pager log -1 --pretty=oneline
info "Target system: $(uname -a)"
info "Kernel version: ${KERNEL_VERSION}"
echo

if [[ -n "$UNKNOWN_SYMS" ]]; then
  warn "Unknown Kconfig symbols in fragments (renamed or removed — these do nothing):"
  echo "$UNKNOWN_SYMS"
  echo
fi

FLIPS=$(grep -E ' (n -> [ym]|[ym] -> n)$' "$DIFF_FILE" || true)
if [[ -n "$FLIPS" ]]; then
  warn "olddefconfig flipped the following options:"
  echo "$FLIPS"
  echo
fi

read -rp "Compile this kernel? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || {
  info "Aborted."
  exit 0
}

# --- Build -------------------------------------------------------------------

info "Starting build ($N_PROC threads)..."
if ! time nice make -j"$N_PROC" \
  CC="ccache gcc" \
  LOCALVERSION="-$LOCALVERSION" \
  INSTALL_MOD_STRIP=1 \
  KCFLAGS="-march=znver4 -mtune=znver4 -pipe" \
  V=$VERBOSITY \
  bindeb-pkg 2>&1 | tee "$SCRIPT_DIR/$BUILD_LOG_FILE"; then
  die "Build failed. Check $SCRIPT_DIR/$BUILD_LOG_FILE for details."
fi

# --- Done --------------------------------------------------------------------
success "Build successful!"
cd "$SCRIPT_DIR" || die "cd back to script dir failed."
echo

DEBS=(
  linux-image-"$KERNEL_VERSION"-"$LOCALVERSION"*.deb
  linux-headers-"$KERNEL_VERSION"-"$LOCALVERSION"*.deb
  linux-libc-dev_"$KERNEL_VERSION"-*.deb
)
info "Packages to install:"
for deb in "${DEBS[@]}"; do printf "    %s\n" "$deb"; done
echo

read -rp "Install now? [y/N] " install_confirm
if [[ "$install_confirm" =~ ^[Yy]$ ]]; then
  sudo dpkg -i "${DEBS[@]}"
  success "Kernel installed. Reboot to use it."
fi
