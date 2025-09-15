_: {
  users.users.namecoin = {
    isSystemUser = true;
    group = "namecoin";
  };
  services = {
    namecoind = {
      enable = true;
      generate = true;
    };
  };
}
