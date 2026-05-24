#!/bin/bash
# Charlie Kirk OS — QEMU Launch Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${SCRIPT_DIR}/charlie-kirk-os.img"
MEM="${MEM:-512M}"
CPUS="${CPUS:-2}"

RED='\033[1;31m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "${IMAGE}" ]; then
    echo -e "${RED}[ERROR]${NC} Image not found: ${IMAGE}"
    echo -e "        Run ${YELLOW}./build.sh${NC} first to build the OS."
    exit 1
fi

echo ""
echo -e "${RED}  Launching Charlie Kirk OS...${NC}"
echo -e "${WHITE}  \"Socialism ends at this boot sequence.\"${NC}"
echo ""
echo -e "  Image : ${IMAGE}"
echo -e "  RAM   : ${MEM}"
echo -e "  CPUs  : ${CPUS}"
echo ""
echo -e "${YELLOW}  TIP: The OS will auto-login as root.${NC}"
echo -e "${YELLOW}  TIP: Pass -nographic to use serial console only.${NC}"
echo -e "${YELLOW}  TIP: Press Ctrl+A X to quit QEMU (serial mode).${NC}"
echo ""

# Detect display availability
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    DISPLAY_OPTS=""
else
    # No display — use serial console only
    DISPLAY_OPTS="-nographic"
    echo -e "  No display detected — running in serial/text mode."
    echo -e "  Press ${YELLOW}Ctrl+A X${NC} to quit."
    echo ""
fi

exec qemu-system-x86_64 \
    -name "Charlie Kirk OS" \
    -machine type=pc,accel=kvm:tcg \
    -cpu host \
    -m "${MEM}" \
    -smp "${CPUS}" \
    -drive file="${IMAGE}",format=raw,if=ide \
    -boot order=c \
    -serial mon:stdio \
    -net nic,model=virtio \
    -net user \
    ${DISPLAY_OPTS} \
    "$@"
