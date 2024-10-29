{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    monero-cli
    monero-gui
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

  services.xmrig = {
    enable = true;
    settings = {
      autosave = true;
      cpu = {
        enable = true;
        max-threads-hint = 50;
      };
      opencl = false;
      cuda = false;
      pools = [
        {
          url = "pool.supportxmr.com:443";
          user = "86FxMgMKate8Vm9Kka41KogveSwYgocQEaiUPgyLq6itBiwh1kch2Y8K5kup91uiTBVKmh8HW4B61U5x5o3hDbMEUrGm5kx";
          keepalive = true;
          tls = true;
        }
      ];
    };
  };
}
