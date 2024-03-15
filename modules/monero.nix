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

  # services.xmrig = {
  #   enable = true;
  #   settings = {
  #     autosave = true;
  #     cpu = true;
  #     opencl = false;
  #     cuda = false;
  #     pools = [
  #       {
  #         url = "pool.supportxmr.com:443";
  #         user = "your-wallet";
  #         keepalive = true;
  #         tls = true;
  #       }
  #     ]
  #   }
  # };
}
