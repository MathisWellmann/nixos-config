let
  user_de_msa2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9KGI7L08vgpSrbArGJk3JDW2jq/T6t3/NmJOxGmQhe";
  system_de_msa2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInemmTsfkJAbLR9IJ3KCnZxpkWzPemkgDvjnSoR9xu7";

  user_desg0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtbndl4uPNgCcQFyffE6yD0sUzp96bhaCQdMHUR6iqN";
  system_desg0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIECiXqvyc2hfQ4vOTGfamVQhzA+KVk2r0AjnVnpx3kTo";

  # de-n5 took over elitedesk's third k3s server slot (etcd quorum member).
  # It has no per-user key pair, so only the host key is a recipient; rekey
  # from de-msa2 or desg0, which do hold user identities.
  system_de_n5 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8Ea4zf+zxU0JZVppnFFLofPlQnzM6W039msFPiSPu+";

  user_meshify = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTrWy6E9iG8lVS1LjISAczHxRHN34mdT9bF1zg6Yh6p";
  system_meshify = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEhdjm6ONHJT5jXHXz04e6AMEXgsTZmTN7W3VleQObkj";
in {
  "k3s_token.age" = {
    publicKeys = [
      user_de_msa2
      system_de_msa2
      user_desg0
      system_desg0
      system_de_n5
    ];
    armor = true;
  };
  # API key of the `clanker` forgejo bot account (hosts/de-msa2/clanker-bot.nix);
  # also used as its git push credential.
  "clanker_forgejo.age" = {
    publicKeys = [
      user_de_msa2
      system_de_msa2
    ];
    armor = true;
  };
  # Private half of the GitHub deploy key (write access to
  # MathisWellmann/nixos-config) the cache builder on desg0 uses to push the
  # updated flake.lock (modules/nixos_cache_builder.nix).
  "nixos-config-deploy-key.age" = {
    publicKeys = [
      user_desg0
      system_desg0
    ];
    armor = true;
  };
  # attic JWT with push access to the `nixos` cache only, for the cache
  # builder on desg0 (modules/nixos_cache_builder.nix). Mint a new one with
  # `sudo atticd-atticadm make-token --sub cache-builder --validity 5y --push nixos`.
  "attic-push-token.age" = {
    publicKeys = [
      user_desg0
      system_desg0
    ];
    armor = true;
  };
  # `ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=...` for atticd's JWT signing
  # (hosts/de-msa2/attic.nix). Regenerating it invalidates every issued token.
  "attic-server-env.age" = {
    publicKeys = [
      user_de_msa2
      system_de_msa2
    ];
    armor = true;
  };
  # `RUSTFS_ACCESS_KEY=...` / `RUSTFS_SECRET_KEY=...` root credentials of the
  # rustfs object store (hosts/de-msa2/rustfs.nix). The same pair is what
  # Agent Substrate's atelet/ate-api-server use as AWS_ACCESS_KEY_ID /
  # AWS_SECRET_ACCESS_KEY.
  "rustfs_env.age" = {
    publicKeys = [
      user_de_msa2
      system_de_msa2
    ];
    armor = true;
  };
  # Bearer token of the `victoriametrics-scraper` ServiceAccount (created by
  # the `nexus` repo), used by victoriametrics for k8s pod discovery.
  "vm_k8s_token.age" = {
    publicKeys = [
      user_de_msa2
      system_de_msa2
    ];
    armor = true;
  };
  # Bearer token of the `meshify-admin` ServiceAccount (env/cluster_access.nix),
  # read by meshify's ~/.kube/k3s.yaml via `tokenFile`. de-msa2's user key is a
  # recipient so it can rekey like every other secret.
  "k3s_meshify_admin_token.age" = {
    publicKeys = [
      user_meshify
      system_meshify
      user_de_msa2
    ];
    armor = true;
  };
}
