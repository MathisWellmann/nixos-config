_: {
  nix.settings = {
    trusted-substituters = [
      # Harmonia runs on port 5000
      "http://de-msa2:5000"
      "https://nix-community.cachix.org"
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      # Harmonia
      "de-msa2:pRornjWlGkufROI/KEK82Y3Okmwkc2cJ+LoJ9kaxtqg="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };
}
