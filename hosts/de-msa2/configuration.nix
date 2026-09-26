# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  global_const = import ../../global_constants.nix;
  const = import ./constants.nix;
  desg0_const = import ./../desg0/constants.nix;
  searx = import ./../../modules/searx.nix {port = const.searx_port;};
  readeck = import ./readeck.nix {
    dir = "/nvme_pool/readeck";
    port = const.readeck_port;
  };
  polaris = import ./../../modules/music_polaris.nix {
    port = const.polaris_port;
    mount_dirs = [
      {
        name = "music";
        source = "/nvme_pool/music";
      }
    ];
  };
  calibre-web = import ./../../modules/calibre_web.nix {port = const.calibre-web_port;};
  mealie = import ./../../modules/mealie.nix {
    port = const.mealie_port;
  };
  sync-starred-github-to-forgejo = import ../../scripts/sync_starred_github_to_forgejo.nix {inherit pkgs;};
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/user_m.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/base_system.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/monero.nix
    ./../../modules/k3s_init.nix
    ./../../modules/ai/local_ai.nix
    (import ./../../modules/ai/oh-my-pi.nix {
      defaultModel = "vllm/${desg0_const.qwen3Model}";
    })
    (import ./../../modules/github_runner.nix {
      repos = ["lfest-rs" "sliding_features-rs" "trade_aggregation-rs" "openresponses-rs"];
    }) # Don't run much load on this host. TODO: move to desg0
    (import ./../../modules/ai/pi-agent.nix {
      baseUrl = "http://meshify:8001/v1";
      vllmBaseUrl = "http://desg0:${toString desg0_const.qwen3_port}/v1";
      vllmModels = [desg0_const.qwen3Model];
    })
    # ./freshrss.nix
    ./nexus_dbs.nix
    ./forgejo.nix
    ./clanker-bot.nix
    ./bencher.nix
    ./dsh.nix
    ./prometheus.nix
    ./alerting.nix
    ./zfs_pool.nix
    ./attic.nix
    ./rustfs.nix
    ./substrate.nix
    ./monty-persona.nix
    ./grafana.nix
    # ./ups.nix
    searx
    # (import ./../../modules/monero_miner.nix {max-threads-hint = 25;})
    readeck
    polaris
    calibre-web
    mealie
  ];

  networking.hostName = "de-msa2"; # Define your hostname.

  systemd = {
    services.sync-starred-github-to-forgejo = {
      description = "Mirror GitHub starred repositories to Forgejo";
      after = ["network-online.target" "forgejo.service"];
      wants = ["network-online.target"];
      requires = ["forgejo.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${sync-starred-github-to-forgejo}/bin/sync-starred-github-to-forgejo";
      };
    };
    timers.sync-starred-github-to-forgejo = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };
  };

  # Token for m's ~/.kube/config (home/de-msa2.nix, env/cluster_access.nix):
  # /etc/rancher/k3s/k3s.yaml is root-only, and running `ax` via sudo leaves
  # root-owned ~/.kube and ~/.ax behind.
  age.secrets.k3s_meshify_admin_token = {
    file = ../../secrets/k3s_meshify_admin_token.age;
    owner = global_const.username;
    mode = "0400";
  };

  # Home manger can silently fail to do its job, so check with `systemctl status home-manager-m`
  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${global_const.username}" = import ./../../home/de-msa2.nix;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  programs.rust-motd = {
    enable = true;
    settings = {
      banner = {
        color = "white";
        command = "${pkgs.fastfetch}/bin/fastfetch";
      };
      filesystems = {
        root = "/";
        external_hdd = "/mnt/external_hdd";
        nvme_pool_magewe = "/nvme_pool/magewe";
        nvme_pool_ilka = "/nvme_pool/ilka";
        nvme_pool_forgejo = "/nvme_pool/forgejo";
        nvme_pool_greptimedb = "/nvme_pool/greptimedb";
        nvme_pool_music = "/nvme_pool/music";
        nvme_pool_pdfs = "/nvme_pool/pdfs";
        nvme_pool_video = "/nvme_pool/video";
      };
      service_status = {
        tailscale = "tailscaled";
        home-manager = "home-manager-m";
        nfs-server = "nfs-server";
        jellyfin = "jellyfin";
        zfs-replication = "zfs-replication";
        zfs-scrub = "zfs-scrub.timer";
        attic = "atticd";
        k3s = "k3s";
        prometheus-node-exporter = "prometheus-node-exporter";
        victoriametrics = "victoriametrics";
        victorialogs = "victorialogs";
        alertmanager = "alertmanager";
        alertmanager-ntfy = "alertmanager-ntfy";
        vmalert = "vmalert-cluster-health";
        sync-starred-github = "sync-starred-github-to-forgejo";
        monero = "monero";
        dragonfly_db = "podman-dragonfly";
        github-runner-lfest-rs = "github-runner-de-msa2-lfest-rs";
        github-runner-trade_aggregation-rs = "github-runner-de-msa2-trade_aggregation-rs";
        github-runner-openresponses-rs = "github-runner-de-msa2-openresponses-rs";
        github-runner-sliding_features-rs = "github-runner-de-msa2-sliding_features-rs";
        uptime-kuma = "uptime-kuma";
        searx = "searx";
        habit-trove = "podman-HabitTrove";
        minidlna = "minidlna";
        readeck = "podman-readeck";
        polaris = "polaris";
        calibre-web = "calibre-web";
        mealie = "mealie";
        immich = "immich-server";
        rustfs = "rustfs";
        forgejo = "forgejo";
        grafana = "grafana";
        vikunja = "vikunja";
        bencher-api = "podman-bencher-api";
        bencher-ui = "podman-bencher-ui";
        ntfy = "ntfy-sh";
        attic-postgres = "postgresql";
        monty = "monty-persona-jeff";
        dsh = "dsh-web";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    const.iperf_port
    const.habit_trove_port
  ];

  # The media drive moved here from the decommissioned `elitedesk` (2026-08-08);
  # same physical btrfs disk, same UUID. `nofail` keeps a boot from hanging if
  # the drive is ever pulled -- this host runs the k3s control plane.
  fileSystems."/mnt/external_hdd" = {
    device = "/dev/disk/by-uuid/e15ce1db-586f-4e7b-a5d8-d8a4a0b45e48";
    fsType = "btrfs";
    options = [
      "users"
      "nofail"
    ];
  };

  services = {
    # Also inherited from elitedesk, serving /mnt/external_hdd.
    jellyfin = {
      enable = true;
      openFirewall = true;
    };
    uptime-kuma = {
      enable = true;
      settings = {
        UPTIME_KUMA_HOST = "0.0.0.0";
        PORT = "${builtins.toString const.uptime_kuma_port}";
      };
    };
    # bitmagnet = {
    #   enable = true;
    #   openFirewall = true;
    #   settings = {
    #     http_server.port = "${builtins.toString const.bitmagnet_port}";
    #   };
    # };
    minidlna = {
      enable = true;
      openFirewall = true;
      settings = {
        friendly_name = "mathis_music";
        media_dir = ["/nvme_pool/music"];
        inotify = "yes";
        port = const.minidlna_port;
      };
    };
    # its a todo list app.
    vikunja = {
      enable = true;
      port = const.vikunja_port;
      # Exposed off-cluster at https://vikunja.k3s.lan through the k3s traefik
      # ingress (see env/host_ingress.nix); fleet-trusted `k3s-lan-ca` cert.
      frontendScheme = "https";
      frontendHostname = "vikunja.k3s.lan";
    };
    immich = {
      enable = true;
      host = "0.0.0.0";
      mediaLocation = "/nvme_pool/immich";
      openFirewall = true;
      port = const.immich_port;
    };
  };

  virtualisation.oci-containers.containers = {
    "HabitTrove" = {
      image = "dohsimpson/habittrove:latest";
      ports = [
        "${builtins.toString const.habit_trove_port}:3000"
      ];
      volumes = [
        "/nvme_pool/habit_trove:/app/data"
      ];
      environmentFiles = [
        "/etc/secrets/habit_trove"
      ];
    };
  };
}
