# Weekly venue-registry run: clone `nexus` (dev), then its
# `skills/venue-registry/scripts/weekly.sh` seeds the list of trading venues,
# lets `pi` refresh each due venue against the desg0 Qwen server and ingests
# the records that validate into the prod ClickHouse (`venue_registry`
# database). See the skill's SKILL.md in nexus.
# Forgejo actions have no `on: schedule` cron trigger, so the timer lives here,
# next to clanker-bot (same host: local Forgejo clone, pi configured).
{
  pkgs,
  config,
  ...
}: let
  const = import ./constants.nix;
  desg0_const = import ./../desg0/constants.nix;
in {
  # Password of the ClickHouse user `venue_registry`, which may only touch
  # its own database (grants in nexus `env/prod.nix`).
  age.secrets.clickhouse_venue_registry = {
    file = ../../secrets/clickhouse_venue_registry.age;
    owner = "m";
  };

  systemd.services.venue-registry = {
    description = "Weekly refresh of the trading venue registry via pi";
    serviceConfig = {
      Type = "oneshot";
      User = "m";
      # ~225 venues are due per week (top 100 plus a quarter of the rest);
      # a new venue took ~45 min on a busy GPU (2026-11-02 Kraken trial).
      # Later runs reuse unchanged pages and are much shorter. systemd never
      # starts a second run while one is active.
      TimeoutStartSec = "6d";
      Environment = "HOME=/home/m";
    };
    path = with pkgs; [
      bash
      gitMinimal
      curl
      jq
      python3
      nix
      # `pi` lives on the system profile, not on a service's default PATH.
      "/run/current-system/sw"
    ];
    environment = {
      CLICKHOUSE_URL = "http://clickhouse.k3s.lan:8123";
      CLICKHOUSE_USER = "venue_registry";
      CLICKHOUSE_PASSWORD_FILE = config.age.secrets.clickhouse_venue_registry.path;
      # Page snapshots must survive runs: they tell which pages changed.
      VR_DATA = "/home/m/.local/share/venue-registry";
      VR_PROVIDER = "vllm";
      VR_MODEL = desg0_const.qwen3Model;
      # Persistent build dir: the clone is fresh every week, the compiled
      # dependencies carry over.
      CARGO_TARGET_DIR = "/home/m/.cache/venue-registry/target";
    };
    script = ''
      set -euo pipefail
      CLICKHOUSE_PASSWORD="$(< "$CLICKHOUSE_PASSWORD_FILE")"
      export CLICKHOUSE_PASSWORD

      workdir="$(mktemp -d)"
      trap 'rm -rf "$workdir"' EXIT
      git clone -q --depth 1 --branch dev "http://localhost:${toString const.forgejo_port}/MathisWellmann/nexus.git" "$workdir/nexus"
      cd "$workdir/nexus"
      if [ ! -x skills/venue-registry/scripts/weekly.sh ]; then
        echo "nexus dev has no skills/venue-registry/scripts/weekly.sh yet" >&2
        exit 1
      fi
      # The CI dev shell: the workspace's pinned toolchain for the build.
      # sglang serves at most 12 requests; leave room for other users.
      nix develop .#ci --command skills/venue-registry/scripts/weekly.sh --jobs 4
    '';
  };

  systemd.timers.venue-registry = {
    description = "Weekly run of venue-registry";
    wantedBy = ["timers.target"];
    timerConfig = {
      # Saturday night: the least competition for the desg0 GPU.
      OnCalendar = "Sat 01:00";
      # Run the catch-up if de-msa2 was off at the scheduled time.
      Persistent = true;
    };
  };
}
