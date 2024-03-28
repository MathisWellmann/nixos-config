{...}: let
  disk_uuid = "/dev/disk/by-uuid/3fa8f257-dcdf-4235-a3c1-ac9100381689";
  backup_hdd = "/mnt/backup_hdd";
in {
  # Mount the backup drive
  fileSystems.${backup_hdd} = {
    device = "${disk_uuid}";
    fsType = "ext4";
    options = [
      # If you don't have this options attribute, it'll default to "defaults"
      "users" # Allows any user to mount and unmount
      "nofail" # Prevent system from failing if this drive doesn't mount
    ];
  };
}
