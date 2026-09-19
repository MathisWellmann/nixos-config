# clanker bot: once a day, clone `nexus`, reconcile the prod and dev clusters
# via nixidy, then let `pi -p` pick one outdated cargo dependency, bump it, and
# open a PR on Forgejo. The systemd unit clones, runs the two nixidy switches
# (always, even when pi bumps nothing) and hands the repo to pi; the agent does
# the picking, git and API work.
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
    file = ../../secrets/clanker_forgejo.age;
    owner = "m";
  };

  systemd.services.clanker-bot = {
    description = "Bump one outdated nexus dependency and open a clanker PR via pi";
    serviceConfig = {
      Type = "oneshot";
      User = "m";
      # A pi session with a handful of tool calls easily outlives systemd's
      # default 90s start timeout for oneshots. 2h covers the first-ever run
      # (nix closure + full workspace build); later runs are incremental.
      TimeoutStartSec = "2h";
      Environment = "HOME=/home/m";
    };
    path = with pkgs; [
      # pi's bash tool needs a shell on PATH; `bash` provides both `bash` and `sh`.
      bash
      gitMinimal
      curl
      jq
      cargo
      cargo-edit
      # The prompt runs `nix develop .#ci` to get cargo-upgrades and the
      # workspace's pinned nightly toolchain (same as Forgejo CI).
      nix
    ];
    environment = {
      # Persistent cargo build dir: the clone is fresh every day, but compiled
      # dependencies carry over, so post-bump checks are incremental.
      CARGO_TARGET_DIR = "/home/m/.cache/clanker-bot/target";
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

            # Always reconcile both clusters on every run; nixidy and the
            # .#prod/.#dev envs live in the nexus flake (same as the .#ci env
            # used below).
            nix run .#nixidy -- switch .#prod
            nix run .#nixidy -- switch .#dev

            # Unquoted heredoc so the service env vars reach the prompt verbatim.
            # No backticks and no command substitutions inside.
            pi_prompt="$(cat <<PROMPT
      You are "clanker", a maintenance bot. The cwd is a fresh checkout of $NEXUS_REPO.
      Bump any outdated Rust dependency if any, and open a pull request on Forgejo.

      1. GET $FORGEJO_API/repos/$NEXUS_REPO/pulls?state=open with the header
         "Authorization: token $CLANKER_TOKEN".
         If any open PR was created by a user with login "clanker":
         a) Rebase the PR branch on the latest base branch ('dev'): fetch origin, checkout the PR's head branch, rebase onto origin/dev, and force-push (`git push -f origin <branch>`).
         b) Check for CI failures by requesting GET $FORGEJO_API/repos/$NEXUS_REPO/commits/<sha>/status or checking status checks on the PR branch.
         c) If CI failed or rebase had conflicts/issues, fix the code/configuration failures, commit the fix, and force-push.
         d) If an open clanker PR exists, focus ONLY on updating, rebasing, and resolving CI failures for that PR. Do not open a new PR. Stop when the existing PR is updated and clean.
      2. Run 'nix develop .#ci --command cargo upgrades' in the repo root to list
         outdated dependencies. If nothing is outdated, stop and say so.
      3. Pick exactly ONE outdated dependency to bump (one PR per run; see step 1).
         Prefer a plain semver-compatible bump; skip tombstone/deprecated releases
         (e.g. a release containing only a compile_error!) and say so instead.
         Bump just that one, then ensure it compiles (cargo check --workspace
         inside the same dev shell) and overall makes sense in the context of
         the dependency.
      4. git checkout -b clanker/bump-<dep>      # replace <dep> with some fitting name.
      5. git config user.name "clanker"
         git config user.email "clanker@forgejo.k3s.lan"
         git add -A
         git commit -m "chore(deps): bump <dep>"
         git push -q origin clanker/bump-<dep>
      6. Build a JSON payload with jq (so the body is escaped properly), then POST it
         to $FORGEJO_API/repos/$NEXUS_REPO/pulls with the headers "Authorization: token
         $CLANKER_TOKEN" and "Content-Type: application/json"; the payload needs head
         ("clanker/bump-<dep>"), base (the repo default branch, "dev"), title
         ("chore(deps): bump <dep>") and a body summarizing the old -> new version.
         Verify the response is HTTP 201 and print the resulting PR url from the JSON.

      Do not push to default branch directly.
      PROMPT
            )"

            # pi is on the system profile (modules/ai/pi-agent.nix), which is not on
            # the default PATH of a service; pin the model so the bot never depends
            # on whatever user m last selected interactively.
            /run/current-system/sw/bin/pi --model "vllm/${desg0_const.qwen3Model}" -p "$pi_prompt"
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
