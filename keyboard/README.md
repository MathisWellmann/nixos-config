# Keyboards

| File | What it is |
|---|---|
| `rsthd.json` | QMK config (Colemak-DH) for the controllerworks mini42 — kept as the source of truth |
| `rsthd.zmk.dts` | Early ZMK keymap draft (mini42 position order; superseded by the generated corne keymap below) |
| `cornemini2/` | ZMK config repo for the **corne mini 2** (nice!nano v2 + corne shields), forked from [KeyboardHoarders/zmk-config-cornemini2](https://github.com/KeyboardHoarders/zmk-config-cornemini2) |

`cornemini2/config/corne.keymap` is the rsthd Colemak-DH keymap, generated from
`rsthd.json` and mapped onto the corne 6-column layout (42 positions, same order
as the mini42 layout). The author's original QWERTY keymap is in git:
`git checkout config/corne.keymap` restores it.

---

## Building (corne mini 2)

Prerequisite: Docker. Everything else (west, Zephyr 3.5 toolchain, ZMK v0.3)
comes from the official ZMK build image; the west workspace
(`zmk/`, `zephyr/`, `.west/` inside `cornemini2/`) is created on first run.

```sh
cd keyboard/cornemini2
docker run --rm -v $(pwd):/workspace -w /workspace zmkfirmware/zmk-build-arm:4.1 bash -c '
  git config --global --add safe.directory "*"
  west zephyr-export
  west build -s zmk/app -d build/left -b nice_nano_v2 -S studio-rpc-usb-uart \
    -- -DZMK_CONFIG=/workspace/config -DSHIELD="corne_left nice_view_adapter nice_view"
  west build -s zmk/app -d build/right -b nice_nano_v2 \
    -- -DZMK_CONFIG=/workspace/config -DSHIELD="corne_right nice_view_adapter nice_view"
'
```

Outputs:

- `cornemini2/build/left/zephyr/zmk.uf2` — left half firmware
- `cornemini2/build/right/zephyr/zmk.uf2` — right half firmware

Rebuilds are incremental. The `-S studio-rpc-usb-uart` snippet is only needed on
the left build (ZMK Studio over USB); it matches the repo's CI matrix.

---

## Flashing

The nRF52840 boots into a USB mass-storage bootloader; you copy the `.uf2` onto
the drive it presents. No extra tools required.

**Important:** ZMK Studio (zmk.studio) is a *runtime* keymap editor, not a
flasher — "flashing" in Studio saves keymap overrides to the keyboard's flash
storage. A Studio-modified keymap overrides the one compiled into the firmware,
and that stored keymap **survives firmware flashes**. After flashing new
firmware, open ZMK Studio and do **Restore Stock Settings** so the compiled
`.keymap` file becomes active again.

**1. Enter the bootloader on one half** — pick whichever applies:

- *Via ZMK Studio* (works with any keymap): connect to the half → unlock
  advanced features (tap the key your current layout maps to `&studio_unlock`,
  e.g. on the System/ADJ layer) → in the keymap editor assign the **Bootloader**
  behavior (Reset section) to any key → save → tap that key. This needs the
  "Bootloader" behavior to be present in the running firmware — true for any
  Studio-enabled build.
- *With the author's original keymap flashed:* hold the **middle right-thumb
  key** (its ADJ-layer key, tap = TAB), release, then tap the **`/` key** —
  outermost key of the right hand's bottom row.
- *With the rsthd keymap flashed:* hold the **middle right-thumb key** (tap =
  SPACE, holds the Fn layer), release, then tap the **outer left-thumb key**
  (`&bootloader`).

The half re-enumerates as a USB drive (vfat).

**2. Copy the matching `.uf2` onto that drive**

- left half  ← `build/left/zephyr/zmk.uf2`
- right half ← `build/right/zephyr/zmk.uf2`

```sh
lsblk -o NAME,SIZE,LABEL,TRAN          # find it: ~33 MiB, usb, no partition table
sudo mount /dev/sdX /mnt/corne_mini
sudo cp build/left/zephyr/zmk.uf2 /mnt/corne_mini/ && sync
sudo umount -l /mnt/corne_mini
```

The bootloader reboots as soon as it has received the last UF2 block — usually
mid-`sync`, before Linux has written the FAT directory entry. A kernel message
like `lost async page write` on the drive is therefore normal and does **not**
mean the flash failed. Repeat for the other half. Do not flash a left build
onto the right half or vice versa.

Without `sync`, `cp` only fills the page cache; the copy reaches the board when
background writeback kicks in (~30 s later), which looks like nothing happened.

*Recovery:* if the board rebooted while `/mnt/corne_mini` was still mounted, the
mount is stale — `ls` on it hangs and `dmesg` spams `FAT-fs (sda): FAT read
failed`. Fix with `sudo umount -l /mnt/corne_mini`, then re-enter the
bootloader and flash again. The board itself is not damaged; the bootloader is
in ROM-protected flash and cannot be broken by a bad copy.

**3. First boot after flashing both halves:** open ZMK Studio, do **Restore
Stock Settings** (clears the stored runtime keymap), then pair the halves —
they link automatically over the split link (USB on the left half only). Both
OLEDs show the active layer name.

---

## rsthd keymap on the corne mini

Layers (hold the layer-tap key, release, then tap):

| Layer | Access key | Contents |
|---|---|---|
| Base | — | Colemak-DH |
| Symbols | inner right-thumb (tap = Enter) | `! " $ { } @ 7-9 - LGUI ' \| & ( ) ' 4-6 + % ? ~ [ ] 0-3 # ESC` |
| Fn | middle right-thumb (tap = Space) | mouse, arrows, F1–F12, `&bootloader` (outer left thumb), `&studio_unlock` (middle left thumb) |
| RGB | middle left-thumb (tap = E) | `RGB_TOG HUI SAI BRI SPI · EFF HUD SAD BRD SPD` |

Known mapping difference vs the mini42: QMK's `RGB_MOD` became `RGB_EFF`
(next effect). If the corne mini board has no outer columns (36-key variant),
positions 0, 11, 12, 23, 24, 35 (LALT, `=`, LSHFT, RSHFT, LGUI, TAB) are dead —
retest and remap onto the thumb cluster if needed.
