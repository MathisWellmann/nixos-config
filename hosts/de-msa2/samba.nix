# Samba (SMB) server sharing the `ilka` dataset to Windows machines on the
# LAN behind a password. The Linux hosts reach the same dataset over NFS
# (exports in zfs_pool.nix); Windows only mounts SMB natively, so it gets
# its own smbd share with a dedicated account instead.
#
# The Samba account is `ilka` (password-only, no unix login). smbd does file
# operations as `m` (force user below) so files written from Windows end up
# owned by uid 1000/users, the same as files written over NFS by meshify and
# razerblade.
#
# The dataset predates this module, so no setup needed. The access password
# lives in secrets/smb_ilka.age (random, like the other secrets;
# change it with `printf '%s\n' '<new password>' \
# | (cd secrets && agenix -e smb_ilka.age)` followed by a switch or
# `sudo systemctl restart samba-password-ilka`).
#
# Windows: browse to `\\de-msa2\ilka` (wsdd below makes it show up in
# Explorer's network view) or map a drive:
#   net use I: \\de-msa2\ilka /user:ilka <password>
{
  config,
  pkgs,
  ...
}: let
  smb_user = "ilka";
  # Identity smbd does file operations as. m is uid 1000, the same uid the
  # NFS clients (meshify, razerblade) write with, so SMB and NFS files share
  # one ownership model.
  file_user = "m";
  share_path = "/nvme_pool/ilka";
in {
  age.secrets.smb_ilka.file = ../../secrets/smb_ilka.age;

  # Unix identity backing the Samba account. It cannot log in (no password
  # hash, locked shell) and only exists so smbd can authenticate `ilka`;
  # file operations go to `file_user` instead.
  users.users.${smb_user} = {
    isSystemUser = true;
    group = smb_user;
    description = "ilka SMB share access";
  };
  users.groups.${smb_user} = {};

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        # Password-only share: never map unknown users to guest, so a wrong
        # user always fails instead of landing on `nobody`.
        "map to guest" = "never";
        # No printers on this host; silence the default print shares.
        "load printers" = "no";
        printing = "bsd";
        "printcap name" = "/dev/null";
        "disable spoolss" = "yes";
      };
      ilka = {
        comment = "ilka share";
        path = share_path;
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = smb_user;
        # Own the files as the NFS clients do, see file_user above.
        "force user" = file_user;
        "create mask" = "0660";
        "directory mask" = "0770";
      };
    };
  };

  # Modern Windows dropped NetBIOS browsing; wsdd answers WS-Discovery
  # requests so `\\de-msa2` still appears in Explorer's network view without
  # a DNS entry.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # agenix -> smbpasswd bridge. The NixOS module creates the daemons but no
  # accounts, so a oneshot (re)applies the password from the secret on every
  # boot and whenever the secret changes. `smbpasswd -a` on an existing user
  # updates its password, so the unit is idempotent.
  systemd.services."samba-password-ilka" = {
    description = "Set the ilka Samba password";
    wantedBy = ["samba.target"];
    after = ["smbd.service"];
    restartTriggers = [config.age.secrets.smb_ilka.file];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = let
      smbpasswd = "${pkgs.samba}/bin/smbpasswd";
    in ''
      pw=$(cat ${config.age.secrets.smb_ilka.path})
      printf '%s\n%s\n' "$pw" "$pw" | ${smbpasswd} -s -a ${smb_user}
      ${smbpasswd} -e ${smb_user}
    '';
  };
}
