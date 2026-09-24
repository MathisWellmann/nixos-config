# monty-persona (inputs.monty-persona): a persistent agent in a Monty REPL.
# One systemd service per persona; `persona monty say|chat|status` works as m
# because the module sets MONTY_PERSONA_DIR system-wide and m is in the
# monty-persona group. The ntfy bridge talks to the local ntfy-sh on :9007
# (see alerting.nix), so the persona is reachable from the phone app on topic
# `jeff`.
{pkgs, ...}: let
  global_const = import ../../global_constants.nix;
  desg0_const = import ../desg0/constants.nix;
  const = import ./constants.nix;

  # Jeff's nix: user-level store under his work dir (persistent, no daemon).
  # The tier 3 jail mounts the work dir as /work, the service process sees it
  # at its real path; nix reads $HOME/.config/nix/nix.conf in both, so one
  # small conf per view, same store.
  jeff = "/var/lib/monty-persona/jeff";
  # ponytail: no nix build sandbox (sandbox=false) - the bwrap jail is the
  # boundary already; nested bwrap buys nothing here.
  jeffNixFlags = "experimental-features = flakes nix-command\\nsandbox = false";
in {
  services.monty-persona = {
    enable = true;
    personas.jeff = {
      premise = ''
        You are Jeff Dean, a persistent developer assistant for m, living in a
        Monty REPL on de-msa2.
        Your job will be to monitor some repos and proactively work on features and care for the health of the codebase.
      '';
      settings = {
        model.name = desg0_const.qwen3Model;
        model.base_url = "http://desg0:${toString desg0_const.qwen3_port}/v1";
        # Life log in dsh layout: $DSH_HOME/sessions with DSH_HOME=/var/lib/monty-persona,
        # so deepseek-harness can browse it; readable for m via the monty-persona group.
        # (Cannot live under /home/m: the home is 0700, the service cannot traverse it.)
        trajectory.sessions_root = "/var/lib/monty-persona/sessions";
        tools.sh = {
          enabled = true; # tier 3 `sh` in the bubblewrap jail
          network = true; # share host netns so git/HTTP work (jail would otherwise have no net)
        };
        # ci_status / ci_log against the local forgejo (forgejo.nix). Plain
        # HTTP on purpose: the persona's rustls only trusts webpki roots, not
        # the fleet's k3s-lan-ca behind https://forgejo.k3s.lan. No token:
        # job logs are only served anonymously (web route, public repos).
        tools.forgejo.base_url = "http://localhost:${toString const.forgejo_port}";
      };
      ntfy = {
        enable = true;
        user = global_const.username;
      };
      # bash registers the tier 3 `sh` tool (it refuses without it); nix on
      # PATH lets jeff pull any dependency into his user store (see below).
      extraPackages = [pkgs.bash pkgs.nix];
      # The service runs under ProtectHome; let it reach the shared sessions root.
      readWritePaths = ["/var/lib/monty-persona/sessions"];
    };
  };

  # Shared dsh sessions root: readable for m via the monty-persona group.
  # nix.conf in both views of the work dir (jail: /work, service: ${jeff}/work);
  # f+ rewrites on every boot, so config changes apply after a reboot.
  systemd.tmpfiles.rules = [
    "d /var/lib/monty-persona/sessions 0770 monty-persona monty-persona -"
    "d ${jeff}/work/.config 0755 monty-persona monty-persona -"
    "d ${jeff}/work/.config/nix 0755 monty-persona monty-persona -"
    "f+ ${jeff}/work/.config/nix/nix.conf 0644 monty-persona monty-persona - store = /work/.nix-store\\n${jeffNixFlags}"
    "d ${jeff}/.config 0755 monty-persona monty-persona -"
    "d ${jeff}/.config/nix 0755 monty-persona monty-persona -"
    "f+ ${jeff}/.config/nix/nix.conf 0644 monty-persona monty-persona - store = ${jeff}/work/.nix-store\\n${jeffNixFlags}"
  ];

  users.users.${global_const.username}.extraGroups = ["monty-persona"];
}
