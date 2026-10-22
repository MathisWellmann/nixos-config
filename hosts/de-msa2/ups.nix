# NUT for the FSP Champ 3KR (USB 0665:5161, Voltronic "QS" protocol).
# Metrics: `nut_exporter` -> victoriametrics job `ups` (`prometheus.nix`).
{config, ...}: let
  nut_user = "nut-admin";
  # agenix (root, 0400). upsd and upsmon read it through systemd
  # credentials set up by the NUT module.
  passwordFile = config.age.secrets.ups_password.path;
  # The exporter runs as a DynamicUser and cannot read the root-only secret,
  # so systemd copies it into the unit's credentials directory instead.
  exporterCredential = "ups_password";
  const = import ./constants.nix;
in {
  age.secrets.ups_password.file = ../../secrets/ups_password.age;

  power.ups = {
    enable = true;
    mode = "standalone";
    ups."UPS-1" = {
      description = "FSP Champ 3KR Fortron";
      # `blazer_usb` is deprecated upstream; `nutdrv_qx` replaces it and
      # was checked against this UPS on 2026-10-22 (reports
      # `driver.version.data: Voltronic 0.12`).
      driver = "nutdrv_qx";
      port = "auto";
      # Pin the device so `port = auto` cannot pick another USB-serial
      # adapter that uses the same Cypress chip.
      directives = [
        "vendorid = 0665"
        "productid = 5161"
      ];
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
      inherit passwordFile;
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
  systemd.services.prometheus-nut-exporter.serviceConfig.LoadCredential = [
    "${exporterCredential}:${passwordFile}"
  ];
  services = {
    prometheus.exporters.nut = {
      enable = true;
      nutUser = nut_user;
      passwordPath = "/run/credentials/prometheus-nut-exporter.service/${exporterCredential}";
      port = const.prometheus_exporter_nut_port;
      # An empty list does not export "all" variables, unlike what the
      # module docs say: nut_exporter then uses its built-in default list,
      # which is mostly `battery.charge*`. This UPS does not report those,
      # so only `ups.load` and `ups.status` came through. The UPS has no
      # `ups.realpower`, so watts = ups.load / 100 * ups.power.nominal *
      # output.powerfactor.
      nutVariables = [
        "battery.runtime"
        "battery.voltage"
        "battery.voltage.nominal"
        "input.frequency"
        "input.voltage"
        "input.voltage.nominal"
        "output.current"
        "output.frequency"
        "output.powerfactor"
        "output.voltage"
        "ups.load"
        "ups.power.nominal"
        "ups.status"
        "ups.temperature"
      ];
    };
  };
}
