#!/usr/bin/env bash
# Flash a UF2 onto a nice!nano (Adafruit nRF52 UF2 bootloader).
# Usage: ./flash.sh <file.uf2> [timeout_s]
# Waits for the bootloader mass-storage device, copies, syncs, unmounts.
set -euo pipefail

uf2=${1:?usage: flash.sh <file.uf2> [timeout_s]}
timeout=${2:-90}
mnt=/mnt/corne_mini

[ -f "$uf2" ] || { echo "no such file: $uf2" >&2; exit 1; }

# leftover from a previous attempt
if mountpoint -q "$mnt" 2>/dev/null; then
    echo "stale mount at $mnt, unmounting"
    sudo umount -l "$mnt"
fi

echo "waiting up to ${timeout}s for the UF2 bootloader drive (double-tap RESET now)..."
dev=""
for ((i = 0; i < timeout; i++)); do
    # bootloader drive: removable, ~32 MiB, vendor "Adafruit"
    dev=$(lsblk -dnpo NAME,SIZE,VENDOR,TYPE 2>/dev/null |
        awk '$4=="disk" && $3 ~ /Adafruit/ {print $1; exit}')
    [ -n "$dev" ] && break
    sleep 1
done
[ -n "$dev" ] || { echo "bootloader drive did not appear" >&2; exit 1; }
echo "found $dev"
sleep 1

sudo mkdir -p "$mnt"
sudo mount "$dev" "$mnt"
echo "copying $(basename "$uf2") ($(stat -c %s "$uf2") bytes)"
sudo cp "$uf2" "$mnt/" && sync || true
# the board reboots as soon as the last block lands; a failed sync is expected
sleep 2
sudo umount -l "$mnt" 2>/dev/null || true

echo "waiting for the board to come back..."
for ((i = 0; i < 20; i++)); do
    if lsusb -d 1d50:615e >/dev/null 2>&1; then
        echo "board re-enumerated as ZMK firmware"
        exit 0
    fi
    sleep 1
done
echo "board did not re-enumerate as ZMK firmware (settings_reset firmware stays in a non-HID state, that is fine)"
