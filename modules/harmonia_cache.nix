{...}: let
  const = import ../hosts/poweredge/constants.nix;
in {
  services.harmonia = {
    enable = true;
    # generate a public/private key pair like this:
    # $ nix-store --generate-binary-cache-key cache.yourdomain.tld-1 /var/lib/secrets/harmonia.secret /var/lib/secrets/harmonia.pub
    signKeyPaths = ["/var/lib/secrets/harmonia.secret"];
    # Example using sops-nix to store the signing key
    #services.harmonia.signKeyPaths = [ config.sops.secrets.harmonia-key.path ];
    #sops.secrets.harmonia-key = { };
    settings = {
      bind = "0.0.0.0:${builtins.toString const.harmonia_port}";
    };
  };

  # optional if you use allowed-users in other places
  nix.settings.allowed-users = ["harmonia"];

  networking.firewall.allowedTCPPorts = [443 80];

  # security.acme.defaults.email = "wellmannmathis@gmail.com";
  # security.acme.acceptTerms = true;

  # services.nginx = {
  #   enable = true;
  #   recommendedTlsSettings = true;
  #   virtualHosts."nixcache.mwtradingsystems.com" = {
  #     # enableACME = true;
  #     forceSSL = false;

  #     locations."/".extraConfig = ''
  #       proxy_pass http://127.0.0.1:${builtins.toString const.harmonia_port};
  #       proxy_set_header Host $host;
  #       proxy_redirect http:// https://;
  #       proxy_http_version 1.1;
  #       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  #       proxy_set_header Upgrade $http_upgrade;
  #       proxy_set_header Connection $connection_upgrade;
  #     '';
  #   };
  # };
}
