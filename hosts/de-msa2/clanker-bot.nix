# clanker bot: once a day, clone `nexus`, let `pi -p` pick one outdated cargo
# dependency, bump it, and open a PR on Forgejo. The systemd unit only clones
# and hands the repo to pi; the agent does the picking, git and API work.
# Forgejo actions have no `on: schedule` cron trigger, so the timer lives here
# on the host that runs it (de-msa2: local clone URL, pi already configured
# against the desg0 Qwen vLLM server).
{
  pkgs,
  config,
  ...
}: let
  const = import ./constants.nix {};
  desg0_const = import ./../desg0/constants.nix;
  forgejo_url = "http://localhost:${toString const.forgejo_port}";
in {
  # clanker's forgejo API key; doubles as the git push credential.
  # Create it once with:
  #   echo -n "<api-key>" | agenix encrypt clanker_forgejo > secrets/clanker_forgejo.age
  age.secrets.clanker_forgejo = {
    file = ../secrets/clanker_forgejo.age;
    owner = "m";
  };

  systemd.services.clanker-bot = {
    description = "Bump one outdated nexus dependency and open a clanker PR via pi";
    serviceConfig = {
      Type = "oneshot";
      User = "m";
      # A pi session with a handful of tool calls easily outlives systemd's
      # default 90s start timeout for oneshots.
      TimeoutStartSec = "45min";
      Environment = "HOME=/home/m";
    };
    path = with pkgs; [
      gitMinimal
      curl
      jq
      cargo
      cargo-edit
    ];
    environment = {
      CLANKER_TOKEN_FILE = config.age.secrets.clanker_forgejo.path;
      FORGEJO_API = "${forgejo_url}/api/v1";
      NEXUS_REPO = "MathisWellmann/nexus";
    };
    script = ''
            set -euo pipefail

            export CLANKER_TOKEN="$(< "$CLANKER_TOKEN_FILE")"

            workdir="$(mktemp -d)"
            trap 'rm -rf "$workdir"' EXIT
            cd "$workdir"

            git clone -q --depth 1 "http://clanker:$CLANKER_TOKEN@localhost:${toString const.forgejo_port}/$NEXUS_REPO.git" nexus
            cd nexus

            # Unquoted heredoc so the service env vars reach the prompt verbatim.
            # No backticks and no command substitutions inside.
            pi_prompt="$(cat <<PROMPT
      You are "clanker", a maintenance bot. The cwd is a fresh checkout of $NEXUS_REPO.
      Bump any outdated Rust dependency if any, and open a pull request on Forgejo.

      1. GET $FORGEJO_API/repos/$NEXUS_REPO/pulls?state=open with the header
         "Authorization: token $CLANKER_TOKEN".
         If any open PR was created by a user with login "clanker", stop and say so
         (only one clanker PR in flight at a time).
      2. Run 'cargo upgrades' in the nix dev shell (nix develop) to list outdated
         dependencies. If nothing is outdated, stop and say so.
      3. For each outdated dependency create a separate git commit and ensure they compile
         and overall make sense in the context of the dependency.
      4. git checkout -b clanker/bump-<dep>      # replace <dep> with some fitting name.
      5. git config user.name "clanker"
         git config user.email "clanker@forgejo.k3s.lan"
         git add -A
         git commit -m "chore(deps): bump <dep>"
         git push -q origin clanker/bump-<dep>
      6. Build a JSON payload with jq (so the body is escaped properly), then POST it
         to $FORGEJO_API/repos/$NEXUS_REPO/pulls with the headers "Authorization: token
         $CLANKER_TOKEN" and "Content-Type: application/json"; the payload needs head
         ("clanker/bump-<dep>"), title ("chore(deps): bump <dep>") and a body
         summarizing the old -> new version.
         Verify the response is HTTP 201 and print the resulting PR url from the JSON.

      Do not push to the default branch.
      PROMPT
            )"

            # pi is on the system profile (modules/ai/pi-agent.nix), which is not on
            # the default PATH of a service; pin the model so the bot never depends
            # on whatever user m last selected interactively.
            /run/current-system/sw/bin/pi -m "vllm/${desg0_const.qwen3Model}" -p "$pi_prompt"
    '';
  };

  systemd.timers.clanker-bot = {
    description = "Daily run of clanker-bot";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "daily";
      # Run the catch-up if de-msa2 was off at the scheduled time.
      Persistent = true;
    };
  };
}
