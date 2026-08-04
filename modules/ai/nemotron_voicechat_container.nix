# NVIDIA Nemotron VoiceChat (11B) real-time speech-to-speech microservice.
# <https://github.com/NVIDIA-NeMo/Speech/blob/nemotron-labs-voicechat/voicechat_realtime_instructions/deploy.md>
# Model card: <https://huggingface.co/nvidia/NVIDIA-NemotronLabs-VoiceChat-11B>
#
# Serves a bidirectional WebSocket at `ws://<host>:<port>/v1/realtime`;
# health probe at `http://<host>:<port>/v1/health/ready` (may take ~5 min).
# Requires ~66 GB VRAM and the NGC API key at /etc/secrets/ngc_api_key
# (`$oauthtoken` login) to pull the image from nvcr.io. The Triton model
# repository itself downloads anonymously from the NGC API.
{
  port ? 9000,
  username ? "m",
  modelVersion ? "2.0.0",
  imageTag ? "latest",
  # Pass e.g. "0" to pin the container to a single GPU.
  gpuDevice ? "all",
}: {pkgs, ...}: let
  stateDir = "/home/${username}/.cache/nemotron-voicechat";
  modelDir = "${stateDir}/nemotron-voicechat_v${modelVersion}";

  # Replicates `ngc registry model download-version nim/nvidia/nemotron-voicechat:<version>`
  # without needing the (unpackaged) NGC CLI: the versions/files endpoint hands
  # out short-lived signed URLs for every file in the Triton model repository.
  downloadScript = pkgs.writeShellApplication {
    name = "nemotron-voicechat-download";
    runtimeInputs = with pkgs; [curl jq coreutils];
    text = ''
      DEST="${modelDir}"
      MARKER="$DEST/.download-complete"

      if [ -f "$MARKER" ]; then
        echo "Model repository already present at $DEST, skipping download."
        exit 0
      fi

      mkdir -p "$DEST"
      listing=$(curl -fsSL \
        "https://api.ngc.nvidia.com/v2/models/org/nim/team/nvidia/nemotron-voicechat/${modelVersion}/files?page-size=1000")

      jq -r '[.filepath, .urls] | transpose[] | @tsv' <<<"$listing" \
        | while IFS=$'\t' read -r filepath url; do
          out="$DEST/$filepath"
          mkdir -p "$(dirname "$out")"
          echo "Downloading $filepath"
          curl -fL --retry 5 --continue-at - -o "$out" "$url"
        done

      # The container (running as a non-root UID) writes into the repo.
      chmod -R 777 "$DEST"
      touch "$MARKER"
      echo "Model repository download complete."
    '';
  };
  clientPython = pkgs.python3.withPackages (ps:
    with ps; [
      websockets
      soundfile
      numpy
      pyaudio
    ]);

  # The reference client only ships inside the container at
  # /s2s/nemotron-voicechat-client.py. This wrapper extracts it once
  # (oci-containers run under root podman, hence sudo) and runs it against
  # the local server. Mic in / speaker out by default; see --help for
  # file-based I/O and function-calling flags.
  clientScript = pkgs.writeShellApplication {
    name = "nemotron-voicechat-client";
    runtimeInputs = [clientPython];
    text = ''
      CLIENT="${stateDir}/nemotron-voicechat-client.py"
      if [ ! -f "$CLIENT" ]; then
        echo "Extracting client script from the running container..."
        sudo podman cp nemotron-voicechat:/s2s/nemotron-voicechat-client.py "$CLIENT"
        sudo chmod 644 "$CLIENT"
      fi
      exec python3 "$CLIENT" --server ws://localhost:${toString port} "$@"
    '';
  };
in {
  networking.firewall.allowedTCPPorts = [port];
  environment.systemPackages = [clientScript];
  hardware.nvidia-container-toolkit.enable = true;

  systemd.services.nemotron-voicechat-download = {
    description = "Download Nemotron VoiceChat Triton model repository";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${downloadScript}/bin/nemotron-voicechat-download";
      # ~30 GB of model weights on first boot.
      TimeoutStartSec = "6h";
    };
  };

  systemd.services.podman-nemotron-voicechat = {
    after = [
      "nvidia-container-toolkit-cdi-generator.service"
      "nemotron-voicechat-download.service"
    ];
    requires = [
      "nvidia-container-toolkit-cdi-generator.service"
      "nemotron-voicechat-download.service"
    ];
    # The image pull 403s until the NGC Early Access entitlement is granted
    # (see <https://developer.nvidia.com/nemotron-voicechat-early-access>).
    # Back off instead of hammering nvcr.io every ~3s forever.
    serviceConfig = {
      RestartSec = "5min";
      RestartMaxDelaySec = "1h";
      RestartSteps = 5;
    };
    unitConfig.StartLimitIntervalSec = 0;
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.nemotron-voicechat = {
      image = "nvcr.io/nim/nvidia/nemotron-voicechat:${imageTag}";

      login = {
        registry = "nvcr.io";
        username = "$oauthtoken";
        passwordFile = "/etc/secrets/ngc_api_key";
      };

      entrypoint = "/s2s/run_s2s_server.sh";

      ports = ["${toString port}:9000"];

      volumes = ["${modelDir}:/data/models"];

      environment = {
        NIM_HTTP_API_PORT = "9000";
      };

      extraOptions = [
        "--device=nvidia.com/gpu=${gpuDevice}"
        "--shm-size=8g"
        "--ipc=host"
      ];
    };
  };
}
