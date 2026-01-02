# TODO: Not entirely working end-to-end yet.
{...}: let
  nut_user = "nut-admin";
  passwordFile = "/etc/ups-passwd.txt";
  const = import ./constants.nix;
in {
  power.ups = {
    enable = true;
    mode = "standalone";
    ups."UPS-1" = {
      description = "FSP Champ 3KR Fortron";
      driver = "blazer_usb";
      port = "auto";
    };
    upsd = {
      listen = [
        {
          address = "127.0.0.1";
          port = 3493;
        }
      ];
    };
    users."${nut_user}" = {
      passwordFile = "/etc/ups-passwd.txt";
      upsmon = "primary";
    };
    upsmon.monitor."UPS-1" = {
      system = "UPS-1@localhost";
      powerValue = 1;
      user = nut_user;
      type = "primary";
      inherit passwordFile;
    };
  };
  services = {
    prometheus.exporters.nut = {
      enable = true;
      nutUser = nut_user;
      passwordPath = passwordFile;
      port = const.prometheus_exporter_nut_port;
    };
  };
}
