{...}: let
  survivor_mount = "/mnt/survivor";
  survivor_uuid = "9DD2-3C7B";
in {
  fileSystems."${survivor_mount}" = {
    device = "/dev/disk/by-uuid/${survivor_uuid}";
    fsType = "vfat";
    options = [
      # If you don't have this options attribute, it'll default to "defaults"
      "users" # Allows any user to mount and unmount
      "nofail" # Prevent system from failing if this drive doesn't mount
    ];
  };
}
