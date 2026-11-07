# Keep a desktop VM's persistent disk image encrypted at rest.
#
# QEMU opens the qcow2 image with its built-in LUKS support, so the guest sees
# a normal disk and needs no initrd changes. The host only ever writes
# ciphertext. The passphrase reaches QEMU through a pipe on fd 3. It never
# touches the disk and never shows up in `ps`.
#
# The VM must be started with `system.build.encryptedVm` (bin/<name>-vm),
# not with the plain `run-<name>-vm` script. That script creates a plaintext
# image when none exists and cannot pass the passphrase.
{
  config,
  lib,
  pkgs,
  ...
}: let
  vmCfg = config.virtualisation.vmVariant.virtualisation;
  name = "${config.system.name}-vm";
  # The label qemu-vm.nix mounts as `/` (its `rootFilesystemLabel`).
  rootLabel = "nixos";

  launcher = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      coreutils
      e2fsprogs
      gnugrep
      qemu-utils
    ];
    text = ''
      usage() {
        echo "usage: ${name}                    start the VM (creates an encrypted disk image on first run)"
        echo "       ${name} convert OLD.qcow2  encrypt a plaintext disk image into the VM's disk image"
      }

      img=$(readlink -f "''${NIX_DISK_IMAGE:-${vmCfg.diskImage}}")
      pass=""

      read_passphrase() {
        read -rsp "Passphrase for $img: " pass
        echo >&2
      }

      new_passphrase() {
        local again
        read -rsp "New passphrase for $img: " pass
        echo >&2
        read -rsp "Repeat the passphrase: " again
        echo >&2
        if [[ -z "$pass" ]]; then
          echo "error: the passphrase is empty" >&2
          exit 1
        fi
        if [[ "$pass" != "$again" ]]; then
          echo "error: the passphrases differ" >&2
          exit 1
        fi
      }

      # $1: source image, $2: its format. Writes the encrypted copy to $img.
      encrypt_into_img() {
        qemu-img convert -f "$2" -O qcow2 \
          --object secret,id=key,file=/dev/fd/3 \
          -o encrypt.format=luks,encrypt.key-secret=key \
          "$1" "$img" 3< <(printf %s "$pass")
      }

      case "''${1:-}" in
        "") ;;
        convert)
          old=''${2:?usage: ${name} convert OLD.qcow2}
          if [[ -e "$img" ]]; then
            echo "error: $img already exists" >&2
            exit 1
          fi
          new_passphrase
          encrypt_into_img "$old" qcow2
          echo "Encrypted $old into $img."
          echo "$old is still plaintext. Delete it, then run 'sudo fstrim -v <its mount point>' so the SSD discards its blocks."
          exit 0
          ;;
        *)
          usage >&2
          exit 1
          ;;
      esac

      if [[ ! -e "$img" ]]; then
        echo "Creating the encrypted disk image $img."
        new_passphrase
        # An empty filesystem holds no secrets, so it is built in plaintext
        # and then encrypted, the same way qemu-vm.nix builds its image.
        tmp=$(mktemp)
        qemu-img create -q -f raw "$tmp" ${toString vmCfg.diskSize}M
        mkfs.ext4 -q -L ${rootLabel} "$tmp"
        encrypt_into_img "$tmp" raw
        rm "$tmp"
      elif qemu-img info -U "$img" | grep -q '^encrypted: yes$'; then
        read_passphrase
      else
        echo "error: $img is not encrypted. Encrypt it with:" >&2
        echo "  mv $img $img.plain && ${name} convert $img.plain" >&2
        exit 1
      fi

      NIX_DISK_IMAGE=$img exec ${config.system.build.vm}/bin/run-${name} 3< <(printf %s "$pass")
    '';
  };
in {
  virtualisation.vmVariant.virtualisation = {
    qemu.options = ["-object secret,id=rootkey,file=/dev/fd/3"];
    # Replaces qemu-vm.nix's root drive (a list entry cannot be merged into)
    # and adds the key. Same options otherwise.
    qemu.drives = lib.mkForce [
      {
        name = "root";
        file = ''"$NIX_DISK_IMAGE"'';
        driveExtraOpts = {
          format = "qcow2";
          "encrypt.key-secret" = "rootkey";
          cache = "writeback";
          werror = "report";
        };
        deviceExtraOpts = {
          bootindex = "1";
          serial = "root";
        };
      }
    ];
  };

  system.build.encryptedVm =
    # The launcher builds the image itself, so it must match the layout the
    # default qemu-vm.nix settings expect. mkForce on the drives above would
    # also drop the Nix store image drive.
    assert lib.assertMsg (vmCfg.diskImage != null) "encrypted-disk.nix needs a persistent disk image";
    assert lib.assertMsg (!vmCfg.useBootLoader) "encrypted-disk.nix does not support useBootLoader";
    assert lib.assertMsg vmCfg.useDefaultFilesystems "encrypted-disk.nix needs useDefaultFilesystems";
    assert lib.assertMsg (!vmCfg.useNixStoreImage) "encrypted-disk.nix does not support useNixStoreImage"; launcher;
}
