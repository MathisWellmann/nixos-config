{
  port ? 3010,
  mount_dirs ? [
    {
      name = "music";
      source = "/nvme_pool/music";
    }
  ],
}: {
  services.polaris = {
    enable = true;
    openFirewall = true;
    inherit port;
    settings = {
      inherit mount_dirs;
    };
  };
}
