{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    monero-cli
  ];
  services.monero = {
    enable = true;
    rpc = {
      address = "0.0.0.0";
      port = 18081;
      restricted = true;
    };
    extraConfig = "confirm-external-bind=true";
  };
  networking.firewall.allowedTCPPorts = [18081];
}
