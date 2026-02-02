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
    hongdown.url = "github:dahlia/hongdown";

    # Local paths
    # tikr = {
    #   url = "path:/home/m/MathisWellmann/tikr";
    #   inputs.nixpkgs.follows = "nixpkgs-unstable";
    # };
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
          # inputs.tikr.nixosModules."x86_64-linux".default
        ];
      };
      de-rosen = nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/de-rosen/configuration.nix
          {_module.args = inputs;}
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
      };
    };
  };
}
