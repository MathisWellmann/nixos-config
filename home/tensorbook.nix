{
  lib,
  pkgs,
  ...
}: let
  wallpaper = "~/wallpaper_animated_orange_train_at_sunset_3840x2160.gif";
in {
  imports = [
    ./home_hyprland.nix
    ./deepseek-harness.nix
  ];
  # DeepSeek Harness (`dsh`), pointed at the vLLM server on `desg0`.
  programs.deepseek-harness = {
    enable = true;
    llmProviders.vllm-desg0 = {
      displayName = "vLLM desg0";
      api = "openai-completions";
      baseURL = "http://desg0:8000/v1";
      # vLLM is unauthenticated here, but the route still declares api-key
      # auth; `VLLM_API_KEY` below is a placeholder vLLM ignores.
      apiKeyEnv = "VLLM_API_KEY";
      # vLLM reports `max_model_len` 131072 for this deployment.
      defaultContextWindow = 131072;
      defaultMaxTokens = 32768;
      # Ids must match `/v1/models` exactly.
      models = [
        {
          id = "Qwen/Qwen3.8-27B-FP8";
          name = "Qwen3.8 27B FP8";
        }
      ];
    };
    defaultModel = {
      provider = "vllm-desg0";
      model = "Qwen/Qwen3.8-27B-FP8";
    };
    plugins = {
      "cyber-particle" = pkgs.fetchFromGitHub {
        owner = "AKS1st";
        repo = "dsh-cyber-particle";
        rev = "master";
        hash = "sha256-2FP4duo1rO4WfNMsDhq3uxU+6EqRst7tAgmNA0XHmCA=";
      };
    };
    # Satisfies the route's `apiKeyEnv` without a login shell: vLLM ignores the
    # value, it only has to exist.
    dotenv.VLLM_API_KEY = "unused-by-vllm";
  };

  wayland.windowManager.hyprland = {
    settings = {
      # Replaces the old `exec-once`.
      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
                hl.exec_cmd("ashell")
                hl.exec_cmd("hyprctl setcursor 'Banana' 48")
                hl.exec_cmd("mpvpaper DP-4 ${wallpaper} -o 'loop' --fork")
              end'')
          ];
        }
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        # London
        {
          output = "DP-6";
          mode = "3840x2160@60";
          position = "0x0";
          scale = 1;
          transform = 1;
        }
        {
          output = "HDMI-A-1";
          mode = "3840x2160@60";
          position = "2160x0";
          scale = 1;
          transform = 1;
        }
        {
          output = "eDP-1";
          mode = "1920x1200@60";
          position = "4320x2760";
          scale = 1;
        }
      ];
      config.cursor.no_hardware_cursors = true;
    };
  };
  services = {
    hyprpaper = {
      enable = true;
      settings = {
        ipc = "on";
        splash = true;
        splash_offset = 2;
        # Convert single image into slices using `imagemagick`:
        # convert -extract 2160x3840+X_OFFSET+0 SOURCE TARGET
        # NOTE: hyprpaper >=0.8 uses `wallpaper { }` blocks; the old
        # `preload = ...` + `wallpaper = "monitor,path"` flat syntax is ignored.
        wallpaper = [
          {
            monitor = "DP-6";
            path = "/home/m/acapulco_wallpaper_0.jxl";
          }
          {
            monitor = "HDMI-A-1";
            path = "/home/m/acapulco_wallpaper_1.jxl";
          }
        ];
      };
    };
  };
  home.packages = with pkgs; [
    stripe-cli
    devbox
    claude-code
  ];
}
