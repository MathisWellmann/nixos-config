{
  pkgs,
  inputs,
  ...
}: {
  services.ollama = let
    system = pkgs.system;
    pkgs-stable = import inputs.nixpkgs-stable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    enable = true;
    acceleration = "cuda";
    # An unstable build has failed, so taking package from stable here.
    package = pkgs-stable.ollama;
  };
}
