# MiniMax Music 3: text-to-music (lyrics + caption -> 32 kHz stereo WAV song),
# served through SGLang-Omni.
#
# Model card: <https://huggingface.co/MiniMaxAI/MiniMax-Music3>
# Cookbook:   <https://sgl-project.github.io/sglang-omni/cookbook/minimax_music3.html>
#
# Exposes the OpenAI speech endpoint at `http://<host>:<port>/v1/audio/speech`:
# lyrics go into `input` (structure tags like `[Verse]` on their own line),
# the style/instrumentation caption into `instructions`. `max_new_tokens` caps
# audio frames at 25 fps (9000 = six minutes, the model's hard limit).
# `temperature`/`top_p`/`voice`/`speed`/`stream: true` are *rejected* by this
# model, sampling is fixed (CFG 1.5 + top-k 50 with a per-request seed).
#
# The `minimax-music3` CLI wrapper installed by this module wraps the curl call.
{
  port ? 8002,
  username ? "m",
  model ? "MiniMaxAI/MiniMax-Music3",
  # Only the `dev` tag is published; it ships the CUDA/UCX/flash-attn runtime and
  # sglang-omni's dependencies, and its entrypoint clones+installs sglang-omni
  # itself into /workspace on every start (hence the persistent workspace volume
  # and the network dependency at service start).
  image ? "docker.io/hongccc/sglang-omni:dev",
  # Pass e.g. "0" to pin the server to a single GPU. With two visible GPUs
  # SGLang-Omni puts the AR stage on the first and the DIT/DAV stage on the second.
  gpuDevice ? "all",
  # Admission limit. Guidance gives every request a second decode row, so this
  # costs KV cache twice as fast as the number suggests.
  maxRunningRequests ? 4,
  # Share of *total* device memory for the backbone KV cache; the acoustic
  # stage's weights live outside it. Upstream defaults to 0.5, kept low here
  # because the same GPU also serves vLLM (0.35) and llama.cpp on `desg0`.
  memFractionStatic ? "0.2",
}: {pkgs, ...}: let
  hf = pkgs.callPackage ../../pkgs/hf.nix {};

  stateDir = "/home/${username}/.cache/minimax-music3";
  modelDir = "${stateDir}/model";
  # The image's entrypoint keeps the sglang-omni checkout here, so persisting it
  # turns the per-start `git clone` into a cheap `git pull --ff-only`.
  workspaceDir = "${stateDir}/workspace";
  inductorCacheDir = "${stateDir}/torchinductor";

  # ~57 GB across the SGLang (`qwen_7B/`, `flowmatching_vae.pth`, `dav.pth`) and
  # diffusers (`language_model/`, `transformer/`) layouts of the repo. Serving
  # from a local dir keeps the container off the network for weights.
  downloadScript = pkgs.writeShellApplication {
    name = "minimax-music3-download";
    runtimeInputs = [hf pkgs.coreutils];
    text = ''
      DEST="${modelDir}"
      MARKER="$DEST/.download-complete"

      if [ -f "$MARKER" ]; then
        echo "Model already present at $DEST, skipping download."
        exit 0
      fi

      mkdir -p "$DEST"
      hf download ${model} --local-dir "$DEST"
      touch "$MARKER"
      echo "Model download complete."
    '';
  };

  clientScript = pkgs.writeShellApplication {
    name = "minimax-music3";
    runtimeInputs = with pkgs; [curl jq coreutils];
    text = ''
      BASE_URL="http://127.0.0.1:${toString port}"
      LYRICS=""
      CAPTION=""
      SEED=0
      # 750 frames = at most 30 seconds; the cheapest way to iterate on a caption.
      FRAMES=750
      OUT="song.wav"

      usage() {
        cat <<'EOF'
      Usage: minimax-music3 [options]

        --lyrics TEXT        Lyrics; put [Verse]/[Chorus]/... on their own line ("\n")
        --lyrics-file FILE   Read the lyrics from FILE instead
        --caption TEXT       Style/instrumentation/tempo/mood description (required)
        --caption-file FILE  Read the caption from FILE instead
        --seed N             Seed, fixes the output for a request (default 0)
        --frames N           Frame cap at 25 fps, max 9000 (default 750 = 30s)
        --out FILE           Output WAV path (default song.wav)
        --base-url URL       Server base URL (default http://127.0.0.1:${toString port})
      EOF
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --lyrics) LYRICS="$2"; shift 2 ;;
          --lyrics-file) LYRICS="$(cat "$2")"; shift 2 ;;
          --caption) CAPTION="$2"; shift 2 ;;
          --caption-file) CAPTION="$(cat "$2")"; shift 2 ;;
          --seed) SEED="$2"; shift 2 ;;
          --frames) FRAMES="$2"; shift 2 ;;
          --out) OUT="$2"; shift 2 ;;
          --base-url) BASE_URL="$2"; shift 2 ;;
          -h|--help) usage; exit 0 ;;
          *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
        esac
      done

      if [ -z "$LYRICS" ] || [ -z "$CAPTION" ]; then
        echo "Both lyrics and a caption are required (both must be non-empty)." >&2
        usage >&2
        exit 2
      fi

      # `printf %b` so `\n` in --lyrics reaches the model as a real newline: the
      # normalizer drops anything sharing a line with a structure tag.
      payload=$(jq -n \
        --arg model "${model}" \
        --arg input "$(printf '%b' "$LYRICS")" \
        --arg instructions "$CAPTION" \
        --argjson seed "$SEED" \
        --argjson max_new_tokens "$FRAMES" \
        '{$model, $input, $instructions, $seed, $max_new_tokens,
          response_format: "wav", stream: false}')

      curl -fsS -X POST "$BASE_URL/v1/audio/speech" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        --max-time 1800 \
        --output "$OUT"

      echo "Wrote $OUT"
    '';
  };
in {
  networking.firewall.allowedTCPPorts = [port];
  environment.systemPackages = [clientScript];
  hardware.nvidia-container-toolkit.enable = true;

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 ${username} users -"
    "d ${workspaceDir} 0755 ${username} users -"
    "d ${inductorCacheDir} 0755 ${username} users -"
  ];

  systemd.services.minimax-music3-download = {
    description = "Download the MiniMax Music 3 weights from Hugging Face";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Own the weights as the user, not root: they live under the user's cache.
      User = username;
      Group = "users";
      ExecStart = "${downloadScript}/bin/minimax-music3-download";
      # ~57 GB on first boot.
      TimeoutStartSec = "12h";
    };
  };

  systemd.services.podman-minimax-music3 = {
    after = [
      "nvidia-container-toolkit-cdi-generator.service"
      "minimax-music3-download.service"
    ];
    requires = [
      "nvidia-container-toolkit-cdi-generator.service"
      "minimax-music3-download.service"
    ];
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.minimax-music3 = {
      inherit image;
      ports = ["${toString port}:8000"];

      volumes = [
        "${modelDir}:/models:ro"
        "${workspaceDir}:/workspace"
        # The image only ships a prebuilt FlashInfer JIT cache for SM89/SM90a, so
        # other architectures (Blackwell) compile their own on first start --
        # persist it, and the torch.compile artifacts for the DIT/DAV stage too.
        "/home/${username}/.cache/flashinfer:/root/.cache/flashinfer"
        "${inductorCacheDir}:/root/.cache/torchinductor"
      ];

      environment = {
        TORCHINDUCTOR_CACHE_DIR = "/root/.cache/torchinductor";
      };

      extraOptions = [
        "--device=nvidia.com/gpu=${gpuDevice}"
        "--ipc=host"
        "--shm-size=32g"
      ];

      cmd = [
        "sgl-omni"
        "serve"
        "--model-path"
        "/models"
        "--host"
        "0.0.0.0"
        "--port"
        "8000"
        "--max-running-requests"
        "${toString maxRunningRequests}"
        "--mem-fraction-static"
        memFractionStatic
      ];
    };
  };
}
