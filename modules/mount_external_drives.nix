_: let
  survivor_mount = "/mnt/survivor";
  survivor_uuid = "f4249695-fd33-4429-9a13-02547f389b5f";
  kingston_mount = "/mnt/kingston";
  kingston_uuid = "9c7d2ce1-0f96-445e-8645-b61e68894659";
  san_disk_mount = "/mnt/san_disk";
  san_disk_uuid = "be397ee5-a15c-4801-9723-97104ee3e991";
  fiio_card = "/mnt/fiio_card";
  fiio_uuid = "C402-82E0";
  options = [
    "users" # Allows any user to mount and unmount
    "nofail" # Prevent system from failing if this drive doesn't mount
  ];
in {
  fileSystems = {
    "${survivor_mount}" = {
      device = "/dev/disk/by-uuid/${survivor_uuid}";
      fsType = "btrfs";
      inherit options;
    };
    ${kingston_mount} = {
      device = "/dev/disk/by-uuid/${kingston_uuid}";
      fsType = "ext4";
      inherit options;
    };
    ${san_disk_mount} = {
      device = "/dev/disk/by-uuid/${san_disk_uuid}";
      fsType = "ext4";
      inherit options;
    };
    ${fiio_card} = {
      device = "/dev/disk/by-uuid/${fiio_uuid}";
      fsType = "exfat";
      inherit options;
    };
  };
}
