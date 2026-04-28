# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  pkgs,
  ...
}: let
  const = import ./constants.nix {};
  de-msa2_const = import ../../hosts/de-msa2/constants.nix {};
  global_const = import ../../global_constants.nix;
  forgejo_runner = import ./../../modules/forgejo_runner.nix {
    forgejo_url = "http://de-msa2:${toString de-msa2_const.forgejo_port}";
    state_dir = "/etc/forgejo_runner";
    runner_capacity = 6;
  };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/base_system.nix
    ./../../modules/desktop_nvidia.nix
    ./../../modules/bash_aliases.nix
    ./../../modules/german_locale.nix
    ./../../modules/root_pkgs.nix
    ./../../modules/prometheus_exporter.nix
    ./../../modules/nix_binary_cache_client.nix
    ./../../modules/ai/local_ai.nix
    ./../../modules/ai/ollama.nix
    (import ./../../modules/github_runner.nix {repos = ["symbiont"];})
    (import ./../../modules/ai/pi-agent.nix {
      baseUrl = "http://localhost:${toString const.llama-cpp_port}/v1";
      enableAgentica = true;
    })
    (import ./../../modules/ai/llama-cpp.nix {
      models = [
        "unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_M"
      ];
      port = const.llama-cpp_port;
    })

    forgejo_runner
    inputs.home-manager.nixosModules.default
  ];

  networking = {
    hostName = const.hostname;
    # hostId can be generated with `head -c4 /dev/urandom | od -A none -t x4`
    hostId = "1840e132";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${global_const.username} = {
    isNormalUser = true;
    description = global_const.username;
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.nushell;
    packages = with pkgs; [
      vllm
    ];
  };

  home-manager = {
    # also pass inputs to home-manager modules
    extraSpecialArgs = {inherit inputs;};
    users = {
      "${global_const.username}" = import ./../../home/home.nix;
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
        color = "black";
        command = "${pkgs.fastfetch}/bin/fastfetch";
      };
      filesystems = {
        root = "/";
      };
      service_status = {
        tailscale = "tailscaled";
        prometheus-exporter = "prometheus-node-exporter";
        restic-backups-home = "restic-backups-home";
        forgejo_runner = "gitea-runner-default";
        github_runner_symbiont = "github-runner-symbiont";
      };
      uptime.prefix = "up";
    };
  };
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = const.open-webui_port;
    openFirewall = true;
  };

  nix.settings.system-features = ["nixos-test" "benchmark" "big-parallel" "kvm"];

  virtualisation = {
    docker.enable = true;
    podman.enable = true;
  };
}
