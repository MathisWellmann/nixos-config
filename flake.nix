{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    lan-mouse.url = "github:feschber/lan-mouse";

    # Local paths
    tikr = {
      url = "path:/home/magewe/MathisWellmann/tikr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    agenix,
    ...
  } @ inputs: {
    nixosConfigurations = {
      meshify = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/meshify/configuration.nix
          inputs.home-manager.nixosModules.default
          agenix.nixosModules.default
          {_module.args = inputs;}
        ];
      };
      superserver = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/superserver/configuration.nix
          inputs.home-manager.nixosModules.default
          agenix.nixosModules.default
        ];
      };
      elitedesk = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/elitedesk/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };
      madcatz = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/madcatz/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };
      poweredge = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/poweredge/configuration.nix
          inputs.home-manager.nixosModules.default
        ];
      };
      genoa = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/genoa/configuration.nix
          {_module.args = inputs;}
        ];
      };
    };
  };
}
