{port ? 3011}: {
  services.calibre-web = {
    enable = true;
    listen = {
      ip = "0.0.0.0";
      inherit port;
    };
    openFirewall = true;
  };
}
