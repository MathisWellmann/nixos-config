# Headlong (https://github.com/laude-institute/headlong) — web viewer for
# agent mind logs / trajectory trees. Runs the `headlong-web` CLI from user
# m's live app tree (~/.headlong/app, see home/headlong.nix) on port 8081.
# Exposed off-cluster at https://headlong.k3s.lan through the k3s traefik
# ingress (see env/host_ingress.nix); fleet-trusted `k3s-lan-ca` cert.
{
  inputs,
  pkgs,
  lib,
  ...
}: let
  const = import ./constants.nix;
  global_const = import ../../global_constants.nix;
  headlong = inputs.self.packages."x86_64-linux".headlong;
in {
  systemd.services.headlong-web = {
    description = "Headlong web viewer";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      User = global_const.username;
      Environment = [
        "HOME=/home/${global_const.username}"
        # uv runs the backend, bun builds the viewer frontend on first start
        # (see pkgs/headlong.nix); coreutils for the wrapper's realpath/cp.
        "PATH=${lib.makeBinPath [pkgs.uv pkgs.bun pkgs.coreutils]}"
      ];
      # No ROOT argument: the wrapper serves its own app tree.
      ExecStart = "${headlong}/bin/headlong-web --host 0.0.0.0 --port ${toString const.headlong_web_port}";
    };
  };
}
