_: let
  poweredge_const = import ../hosts/poweredge/constants.nix;
in {
  nix.settings.trusted-substituters = [
    "http://${poweredge_const.hostname}:${builtins.toString poweredge_const.harmonia_port}"
    "http://${poweredge_const.hostname}:${builtins.toString poweredge_const.ncps_port}"
  ];
  nix.settings.trusted-public-keys = [
    # Harmonia
    "poweredge:S7D5KElVnn7cZrQGpoL3Z9X7XRtmk4K9qFcrNoyeoUI="
    # ncps Get public key: `curl -X GET http://poweredge:3501`
    "${poweredge_const.hostname}:/HB255KnBl2OThyoTq40lY0W1OcJaApUq6keekmqudc="
  ];
}
