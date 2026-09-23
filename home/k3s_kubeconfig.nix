# Fleet k3s API kubeconfig as the `meshify-admin` ServiceAccount
# (env/cluster_access.nix). The token is the agenix secret
# `k3s_meshify_admin_token`, which the host must declare (owner m).
{
  pkgs,
  server,
  tokenFile,
}:
(pkgs.formats.yaml {}).generate "k3s.yaml" {
  apiVersion = "v1";
  kind = "Config";
  clusters = [
    {
      name = "k3s";
      cluster = {
        inherit server;
        certificate-authority = "${../modules/k3s-server-ca.crt}";
      };
    }
  ];
  users = [
    {
      name = "meshify-admin";
      user.tokenFile = tokenFile;
    }
  ];
  contexts = [
    {
      name = "k3s";
      context = {
        cluster = "k3s";
        user = "meshify-admin";
      };
    }
  ];
  current-context = "k3s";
}
