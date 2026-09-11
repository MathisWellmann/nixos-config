# Open WebUI frontend for the local SGLang server (see
# sglang_qwen3_container.nix).
{
  port ? 8090,
  # Must be reachable from inside the container, so use
  # host.docker.internal, not 127.0.0.1 (that is the container itself).
  inferenceUrl ? "http://host.docker.internal:8000/v1",
}: {
  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:v0.11.3";
    ports = [ "${toString port}:8080" ];
    # DB, auth and chats survive image updates.
    volumes = [ "/var/lib/open-webui:/app/backend/data" ];
    # nixpkgs's oci-containers has no extraHosts option; pass the flag raw.
    extraOptions = [ "--add-host" "host.docker.internal:host-gateway" ];
    # Built-in OpenAI connection (open_webui/config.py reads these envs).
    environment = {
      OPENAI_API_BASE_URL = inferenceUrl;
      # sglang serves unauthenticated; a non-empty value silences the
      # API-key prompt in the UI.
      OPENAI_API_KEY = "none";
    };
  };

  # Podman fails with a statfs error when the bind source is missing.
  systemd.tmpfiles.rules = [ "d /var/lib/open-webui 0755 root root -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
