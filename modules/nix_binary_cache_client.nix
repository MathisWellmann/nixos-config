{...}: let
  poweredge_const = import ../hosts/poweredge/constants.nix;
in {
  nix.settings.substituters = [
    # TODO: use port from constants file.
    "http://${poweredge_const.hostname}:5000"
    "http://${poweredge_const.hostname}:${builtins.toString poweredge_const.ncps_port}"
  ];
  nix.settings.trusted-public-keys = [
    "${poweredge_const.hostname}:yo2DcCCDywV6ImfqBa3etuuqaYOYmJPX4xzHdRaBmpU="
    "nixcache.mwtradingsystems.com:yo2DcCCDywV6ImfqBa3etuuqaYOYmJPX4xzHdRaBmpU="
    # Get public key: `curl -X GET http://poweredge:3501`
    "${poweredge_const.hostname}:/HB255KnBl2OThyoTq40lY0W1OcJaApUq6keekmqudc="
  ];
}
