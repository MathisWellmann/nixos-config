{
  description = "Nixos config flake";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nox = {
      url = "github:madsbv/nix-options-search";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    # Animated wallpaper daemon written in rust, because `mpvpaper` leaks memory.
    awww.url = "git+https://codeberg.org/LGFae/awww";
    iggy = {
      url = "github:MathisWellmann/iggy/nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";

    # Local paths
    nexus = {
      url = "path:/home/m/MathisWellmann/nexus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
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
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  outputs = {
    self,
    nixpkgs-unstable,
    home-manager,
    ...
  } @ inputs: {
    nixosConfigurations = {
      meshify = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/meshify/configuration.nix
          home-manager.nixosModules.default
          inputs.agenix.nixosModules.default
          inputs.sops-nix.nixosModules.sops
          {_module.args = inputs;}
        ];
      };
      superserver = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/superserver/configuration.nix
          inputs.home-manager.nixosModules.default
          inputs.agenix.nixosModules.default
        ];
      };
      elitedesk = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/elitedesk/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };
      poweredge = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/poweredge/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };
      razerblade = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/razerblade/configuration.nix
          {_module.args = inputs;}
        ];
      };
      desg0 = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/desg0/configuration.nix
          {_module.args = inputs;}
        ];
      };
      de-msa2 = nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/de-msa2/configuration.nix
          {_module.args = inputs;}
        ];
      };
      de-n5 = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/de-n5/configuration.nix
          {_module.args = inputs;}
        ];
      };
      tensorbook = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/tensorbook/configuration.nix
          {_module.args = inputs;}
        ];
      };
    };
    apps = let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs-unstable {
        inherit system;
      };
    in {
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
        claude-local = inputs.flake-utils.lib.mkApp {
          drv = import scripts/claude-local.nix {inherit pkgs;};
        };
      };
    };
  };
}
