# Bencher self-hosted (https://bencher.dev) — continuous benchmarking suite.
#
# Runs the API + Console as two podman containers, fronted off-cluster at
# https://bencher.k3s.lan (console) and https://bencher-api.k3s.lan (API)
# through the k3s traefik ingress (see env/host_ingress.nix); fleet-trusted
# `k3s-lan-ca` cert. The firewall ports stay open as a plain-HTTP fallback.
{pkgs, ...}: let
  const = import ./constants.nix {};

  # Bencher API server config (https://bencher.dev/docs/reference/server-config).
  # Nix-managed: this template carries everything EXCEPT `security.secret_key`,
  # which is injected at runtime from /etc/secrets/bencher_secret_key by the
  # `bencher-config` systemd service below (so the secret never lands in the
  # world-readable nix store). Notes:
  # - `server.bind_address` MUST match the bencher-api container target port
  #   (3000); a mismatch makes the API listen on the wrong port -> every request
  #   is connection-refused -> console shows "Failed to signup: undefined".
  # - `console.url` / `security.issuer` use the real *.k3s.lan ingress hosts so
  #   confirmation links and JWTs are valid for fleet browsers.
  # The literal `@SECRET_KEY@` is replaced at runtime.
  bencherApiConfigTemplate = pkgs.writeText "bencher.json.template" (builtins.toJSON {
    console.url = "https://bencher.k3s.lan";
    security = {
      issuer = "https://bencher-api.k3s.lan";
      secret_key = "@SECRET_KEY@";
    };
    server = {
      bind_address = "0.0.0.0:3000";
      request_body_max_bytes = 1048576;
    };
    logging = {
      name = "Bencher API";
      log.stderr_terminal.level = "info";
    };
    database.file = "/var/lib/bencher/data/bencher.db";
  });
in {
  networking.firewall.allowedTCPPorts = [
    const.bencher_ui_port
    const.bencher_api_port
  ];

  virtualisation.oci-containers.containers = {
    "bencher-api" = {
      image = "ghcr.io/bencherdev/bencher-api:v0.6.8";
      ports = [
        "${toString const.bencher_api_port}:3000"
      ];
      volumes = [
        # Config is rendered by the `bencher-config` systemd service from
        # `bencherApiConfigTemplate` (above) + /etc/secrets/bencher_secret_key.
        "/nvme_pool/bencher/config:/etc/bencher" # Config dir
        "/nvme_pool/bencher/data:/var/lib/bencher/data" # Data dir
      ];
    };
    "bencher-ui" = {
      image = "ghcr.io/bencherdev/bencher-console:v0.6.8";
      ports = [
        "${toString const.bencher_ui_port}:3000"
      ];
      environment = {
        # Browser-facing API URL: fleet browsers load the console at
        # https://bencher.k3s.lan and must reach the API over a routable
        # HTTPS host, not the host-local 127.0.0.1 port. Exposed via the
        # cluster traefik ingress (see env/host_ingress.nix).
        BENCHER_API_URL = "https://bencher-api.k3s.lan";
        INTERNAL_API_URL = "http://host.podman.internal:${toString const.bencher_api_port}";
        # Self-hosted GitHub/Google OAuth require a Bencher Plus Enterprise
        # plan + configured client IDs. Explicitly disabled so the login/signup
        # page shows neither button (only email/password signup).
        OAUTH_GITHUB = "false";
        OAUTH_GOOGLE = "false";
      };
    };
  };

  # Renders the Bencher API server config from `bencherApiConfigTemplate` by
  # substituting `@SECRET_KEY@` with the contents of /etc/secrets/bencher_secret_key.
  # Runs before the bencher-api container starts so the secret stays out of the
  # nix store while the rest of the config remains declarative.
  systemd.services.bencher-config = {
    description = "Render Bencher API server config from template + secret";
    wantedBy = ["multi-user.target"];
    before = ["podman-bencher-api.service"];
    requiredBy = ["podman-bencher-api.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      install -d -m 0755 /nvme_pool/bencher/config
      secret="$(cat /etc/secrets/bencher_secret_key)"
      umask 077
      ${pkgs.gnused}/bin/sed "s|@SECRET_KEY@|$secret|" \
        ${bencherApiConfigTemplate} > /nvme_pool/bencher/config/bencher.json
      chmod 0600 /nvme_pool/bencher/config/bencher.json
    '';
  };
}
