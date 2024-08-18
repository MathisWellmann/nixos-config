# Restic requires a password at `/etc/nixos/secrets/restic/password`
{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    services.backup_home_to_remote = with lib; {
      enable = mkEnableOption "Backup to remote host using restic";
      local_username = mkOption {
        default = "magewe";
        type = types.str;
      };
      backup_host_addr = mkOption {
        type = types.str;
      };
      backup_host_name = mkOption {
        type = types.str;
      };
      backup_host_dir = mkOption {
        type = types.str;
      };
    };
  };
  config = let
    cfg = config.services.backup_home_to_remote;
  in
    lib.mkIf cfg.enable {
      ### Backup Section ###
      fileSystems."/mnt/${cfg.backup_host_name}_backup" = {
        device = "${cfg.backup_host_addr}:${cfg.backup_host_dir}";
        fsType = "nfs";
        options = ["rw" "nofail"];
      };
      services = {
        restic.backups = {
          home = {
            initialize = true;
            paths = [
              "/home/${cfg.local_username}/"
            ];
            exclude = [
              "/home/${cfg.local_username}/.cache/"
            ];
            passwordFile = "/etc/nixos/secrets/restic/password";
            repository = "/mnt/${cfg.backup_host_name}_backup/";
            pruneOpts = ["--keep-daily 14"];
            user = "${cfg.local_username}";
          };
        };
      };
      environment.systemPackages = with pkgs; [
        restic
      ];
    };
}
