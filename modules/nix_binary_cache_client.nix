_: {
  nix.settings = {
    trusted-substituters = [
      # Harmonia runs on port 5000
      "http://de-msa2:5000"
    ];
    trusted-public-keys = [
      # Harmonia
      "de-msa2:pRornjWlGkufROI/KEK82Y3Okmwkc2cJ+LoJ9kaxtqg="
    ];
  };
}
