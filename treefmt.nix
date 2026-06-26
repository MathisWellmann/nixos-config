# treefmt config (consumed by numtide/treefmt-nix).
# Run `nix fmt` to format, or `nix flake check` to verify formatting in CI.
_: {
  projectRootFile = "flake.nix";
  programs = {
    alejandra.enable = true;
    deadnix.enable = true;
    statix.enable = true;
  };
}
