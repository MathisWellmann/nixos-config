_: {
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
  systemd.services.xmrig = {
    serviceConfig = {
      Nice = 15; # Reduce `xmrig` scheduler priority. Higher means lower priority, up to 19.
      CPUWeight = 10; # Default is 100, minimum is 1
      IOSchedulingClass = "idle";
    };
  };
}
