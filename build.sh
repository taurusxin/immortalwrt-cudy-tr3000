#!/bin/bash
#
# Local build script for ImmortalWrt Cudy TR3000 (128M U-Bootmod)
# Usage: ./build.sh [options]
#   --clean      Clean build (remove source and ccache)
#   --menuconfig Run make menuconfig before building
#   --ccache     Enable ccache (default: enabled)
#   --no-ccache  Disable ccache
#   --jobs N     Set parallel jobs (default: nproc)
#

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/openwrt"
OUTPUT_DIR="${SCRIPT_DIR}/firmware"
CONFIG_FILE="config/128muboot.config"
REPO_URL="https://github.com/padavanonly/immortalwrt-mt798x-6.6"
REPO_BRANCH="openwrt-24.10-6.6"
REPO_COMMIT=""
USE_CCACHE=1
RUN_MENUCONFIG=0
CLEAN_BUILD=0
JOBS="$(nproc)"
CCACHE_MAXSIZE="2G"
TZ="Asia/Shanghai"

# ─── Color helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Parse arguments ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)      CLEAN_BUILD=1; shift ;;
        --menuconfig) RUN_MENUCONFIG=1; shift ;;
        --ccache)     USE_CCACHE=1; shift ;;
        --no-ccache)  USE_CCACHE=0; shift ;;
        --jobs)       JOBS="$2"; shift 2 ;;
        --commit)     REPO_COMMIT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --clean        Clean build (remove source and ccache)"
            echo "  --menuconfig   Run make menuconfig before building"
            echo "  --ccache       Enable ccache (default)"
            echo "  --no-ccache    Disable ccache"
            echo "  --jobs N       Set parallel jobs (default: nproc)"
            echo "  --commit HASH  Checkout specific commit"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ─── Check dependencies ─────────────────────────────────────────────────────
check_deps() {
    info "Checking build dependencies..."

    local REQUIRED_PKGS=(
        ack antlr3 asciidoc autoconf automake autopoint binutils bison
        build-essential bzip2 ccache clang cmake cpio curl device-tree-compiler
        ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev
        gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
        libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev
        libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool
        libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano ninja-build
        p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply
        python3-docutils python3-pyelftools qemu-utils re2c rsync scons
        squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip vim wget
        xmlto xxd zlib1g-dev zstd
    )

    local MISSING=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            MISSING+=("$pkg")
        fi
    done

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        warn "Missing packages: ${MISSING[*]}"
        info "Installing missing packages..."
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends "${MISSING[@]}"
    else
        info "All dependencies satisfied."
    fi
}

# ─── Clean build ──────────────────────────────────────────────────────────────
if [[ $CLEAN_BUILD -eq 1 ]]; then
    warn "Clean build requested."
    read -rp "This will delete openwrt/ and ~/.ccache-openwrt. Continue? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$WORK_DIR"
        rm -rf ~/.ccache-openwrt
        info "Cleaned."
    else
        info "Clean cancelled."
    fi
fi

# ─── Set timezone ─────────────────────────────────────────────────────────────
if [[ -f /etc/timezone ]]; then
    sudo timedatectl set-timezone "$TZ" 2>/dev/null || true
fi

# ─── Install dependencies ────────────────────────────────────────────────────
check_deps

# ─── Clone source ────────────────────────────────────────────────────────────
if [[ ! -d "$WORK_DIR" ]]; then
    info "Cloning ImmortalWrt source..."
    git clone "$REPO_URL" -b "$REPO_BRANCH" --single-branch --filter=blob:none "$WORK_DIR"

    if [[ -n "$REPO_COMMIT" ]]; then
        info "Checking out commit: $REPO_COMMIT"
        cd "$WORK_DIR" && git checkout "$REPO_COMMIT"
    fi
else
    info "Source directory exists, skipping clone."
fi

cd "$WORK_DIR"

# ─── Configure ccache ────────────────────────────────────────────────────────
if [[ $USE_CCACHE -eq 1 ]]; then
    info "Configuring ccache..."
    export CCACHE_DIR="${WORK_DIR}/.ccache"
    ccache --set-config=max_size="$CCACHE_MAXSIZE"
    ccache --set-config=compression=true
    ccache -z
fi

# ─── DIY Part 1 (before feeds) ───────────────────────────────────────────────
info "Running diy-part1.sh..."
chmod +x "$SCRIPT_DIR/diy-part1.sh"
"$SCRIPT_DIR/diy-part1.sh"

# ─── Update & Install feeds ──────────────────────────────────────────────────
info "Updating and installing feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# ─── DIY Part 2 (after feeds) ────────────────────────────────────────────────
info "Running diy-part2.sh..."
chmod +x "$SCRIPT_DIR/diy-part2.sh"
"$SCRIPT_DIR/diy-part2.sh"

# ─── Load config ──────────────────────────────────────────────────────────────
info "Loading config: $CONFIG_FILE"
cp -f "$SCRIPT_DIR/$CONFIG_FILE" .config
make defconfig

# ─── Menuconfig (optional) ───────────────────────────────────────────────────
if [[ $RUN_MENUCONFIG -eq 1 ]]; then
    info "Opening menuconfig..."
    make menuconfig
    info "Saving config back to $CONFIG_FILE"
    cp -f .config "$SCRIPT_DIR/$CONFIG_FILE"
fi

# ─── Download sources ────────────────────────────────────────────────────────
info "Downloading package sources (jobs: $JOBS)..."
make download -j"$JOBS"

# ─── Compile ──────────────────────────────────────────────────────────────────
info "Starting compilation (jobs: $JOBS)..."
BUILD_START=$(date +%s)

if [[ $USE_CCACHE -eq 1 ]]; then
    if ! make -j"$JOBS" CC="ccache gcc" CXX="ccache g++"; then
        warn "Multi-threaded build failed, retrying single-threaded..."
        make -j1 V=s
    fi
else
    if ! make -j"$JOBS"; then
        warn "Multi-threaded build failed, retrying single-threaded..."
        make -j1 V=s
    fi
fi

BUILD_END=$(date +%s)
BUILD_DURATION=$(( BUILD_END - BUILD_START ))
BUILD_MINUTES=$(( BUILD_DURATION / 60 ))
BUILD_SECONDS=$(( BUILD_DURATION % 60 ))

# ─── Collect output ──────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
find bin/targets/ -name "*sysupgrade.bin" -exec cp {} "$OUTPUT_DIR/" \;

info "========================================="
info "Build completed in ${BUILD_MINUTES}m ${BUILD_SECONDS}s"
info "Firmware output: $OUTPUT_DIR/"
ls -lh "$OUTPUT_DIR/" 2>/dev/null || warn "No firmware files found."
info "========================================="

if [[ $USE_CCACHE -eq 1 ]]; then
    info "ccache stats:"
    ccache -s
fi
