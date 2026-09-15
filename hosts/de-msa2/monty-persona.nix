# monty-persona (inputs.monty-persona): a persistent agent in a Monty REPL.
# One systemd service per persona; `persona monty say|chat|status` works as m
# because the module sets MONTY_PERSONA_DIR system-wide and m is in the
# monty-persona group. The ntfy bridge talks to the local ntfy-sh on :9007
# (see alerting.nix), so the persona is reachable from the phone app on topic
# `jeff`.
_: let
  global_const = import ../../global_constants.nix;
  desg0_const = import ../desg0/constants.nix;
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
      };
      ntfy = {
        enable = true;
        user = global_const.username;
      };
      # The service runs under ProtectHome; let it reach the shared sessions root.
      readWritePaths = ["/var/lib/monty-persona/sessions"];
    };
  };

  # Shared dsh sessions root: readable for m via the monty-persona group.
  systemd.tmpfiles.rules = ["d /var/lib/monty-persona/sessions 0770 monty-persona monty-persona -"];

  users.users.${global_const.username}.extraGroups = ["monty-persona"];
}
