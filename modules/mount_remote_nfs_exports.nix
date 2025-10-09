# Mount NFS exports from a remote host to `/mnt/`
{
  config,
  lib,
  ...
}: {
  options = {
    services.mount_remote_nfs_exports = with lib; {
      enable = mkEnableOption "Mount NFS exports of remote host";
      nfs_host_name = mkOption {
        type = types.str;
      };
      nfs_host_addr = mkOption {
        type = types.str;
      };
      nfs_dirs = mkOption {
        type = types.listOf types.str;
      };
    };
  };
  config = let
    cfg = config.services.mount_remote_nfs_exports;
  in
    lib.mkIf cfg.enable {
      fileSystems = builtins.listToAttrs (map (dir: let
          local_suffix = lib.replaceStrings ["/"] ["_"] dir;
        in {
          name = "/mnt/${cfg.nfs_host_name}${local_suffix}";
          value = {
            device = "${cfg.nfs_host_addr}:${dir}";
            fsType = "nfs";
            options = ["rw" "nofail"];
          };
        })
        cfg.nfs_dirs);
    };
}
