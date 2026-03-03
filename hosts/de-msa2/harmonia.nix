_: {
  services.harmonia = {
    enable = true;
    # generate a public/private key pair like this:
    # $ nix-store --generate-binary-cache-key cache.yourdomain.tld-1 /var/lib/secrets/harmonia.secret /var/lib/secrets/harmonia.pub
    signKeyPaths = ["/etc/secrets/harmonia.secret"];
  };
  networking.firewall.allowedTCPPorts = [5000]; # Default harmonia port
}
