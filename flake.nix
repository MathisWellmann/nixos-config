{
  description = "Nixos config flake";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    agenix.url = "github:ryantm/agenix";
    nox.url = "github:madsbv/nix-options-search";
    # Animated wallpaper daemon written in rust, because `mpvpaper` leaks memory.
    awww.url = "git+https://codeberg.org/LGFae/awww";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    llm-agents.url = "github:numtide/llm-agents.nix";
    forgecode.url = "github:tailcallhq/forgecode";
    kopuz.url = "github:temidaradev/kopuz";
    stochos.url = "github:museslabs/stochos";
    nixidy.url = "github:arnarg/nixidy";
    dirge.url = "github:dirge-code/dirge";
    maki.url = "github:tontinton/maki";
    # Helm charts packaged as nix derivations, used by nixidy applications.
    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Local paths
    # agentica-framework = {
    #   url = "path:/home/m/symbolica/agentica-framework";
    #   inputs.nixpkgs.follows = "nixpkgs-unstable";
    # };
  };
  # some CUDA packages require like 250GB of RAM to compile from scratch, so use binary caches.
  # Run with `--accept-flake-config`
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos-cuda.org"
      "https://cache.numtide.com"
      "https://kopuz.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "kopuz.cachix.org-1:WXMpGpamblLUiJtcoxBxGGGGwIcWxGPJBUxarLiqWmw="
    ];
  };

  outputs = {
    self,
    nixpkgs-unstable,
    home-manager,
    hermes-agent,
    nixidy,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs-unstable {inherit system;};
    # Build a NixOS configuration for a host in `hosts/<name>/`.
    # `home-manager` is always wired in here so individual host
    # `configuration.nix` files don't each re-import it. `extraModules`
    # carries host-specific flake modules (agenix, sops, hermes-agent, ...).
    mkHost = name: extraModules:
      nixpkgs-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            ./hosts/${name}/configuration.nix
            home-manager.nixosModules.default
            {
              home-manager.useUserPackages = true;
              environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];
            }
          ]
          ++ extraModules;
      };
    treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
  in {
    nixidyEnvs."${system}" = nixidy.lib.mkEnvs {
      inherit pkgs;

      # Makes helm charts available to applications as the `charts` module argument.
      charts = inputs.nixhelm.chartsDerivations.${system};

      envs = {
        prod.modules = [./env/prod.nix];
      };
    };
    packages."${system}" = {
      # The nixidy CLI, e.g. `nix run .#nixidy -- switch .#prod`
      nixidy = nixidy.packages.${system}.default;

      # The Hugging Face `hf` CLI, e.g. `nix run .#hf -- download <repo>`
      hf = pkgs.callPackage ./pkgs/hf.nix {};
    };

    nixosConfigurations = {
      meshify = mkHost "meshify" [
        inputs.agenix.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        hermes-agent.nixosModules.default
        {_module.args = inputs;}
      ];
      superserver = mkHost "superserver" [
        inputs.agenix.nixosModules.default
      ];
      elitedesk = mkHost "elitedesk" [
        inputs.agenix.nixosModules.default
      ];
      poweredge = mkHost "poweredge" [];
      razerblade = mkHost "razerblade" [
        {_module.args = inputs;}
      ];
      desg0 = mkHost "desg0" [
        inputs.agenix.nixosModules.default
        {_module.args = inputs;}
      ];
      de-msa2 = mkHost "de-msa2" [
        inputs.agenix.nixosModules.default
        {_module.args = inputs;}
      ];
      de-n5 = mkHost "de-n5" [
        {_module.args = inputs;}
      ];
      tensorbook = mkHost "tensorbook" [
        {_module.args = inputs;}
      ];
    };
    formatter.${system} = treefmtEval.config.build.wrapper;
    apps = {
      "${system}" = rec {
        default = list_apps;
        list_apps = inputs.flake-utils.lib.mkApp {
          drv = (import ./scripts/list_apps.nix {inherit self pkgs system;}).script;
        };
        zfs_replication = inputs.flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "zfs_replication" (import scripts/zfs_replication.nix {inherit pkgs;});
        };
        wake_on_lan = inputs.flake-utils.lib.mkApp {
          drv = import scripts/wake_on_lan.nix {inherit self pkgs;};
        };
        sync_starred_github_to_forgejo = inputs.flake-utils.lib.mkApp {
          drv = import scripts/sync_starred_github_to_forgejo.nix {inherit pkgs;};
        };
        hf = inputs.flake-utils.lib.mkApp {
          drv = self.packages.${system}.hf;
          name = "hf";
        };
      };
    };
  };
}
