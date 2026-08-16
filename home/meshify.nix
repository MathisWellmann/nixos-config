{lib, ...}: let
  global_const = import ../global_constants.nix;
  wallpaper = "~/wallpaper_vertical_animated_1080_1920_25fps_orange_blue.mp4";
in {
  imports = [
    ./home_hyprland.nix
    ./games.nix
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
      # vLLM reports `max_model_len` 262144 for this deployment.
      defaultContextWindow = 262144;
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
      env = [
        {_args = ["LIBVA_DRIVER_NAME" "nvidia"];}
        {_args = ["XDG_SESSION_TYPE" "wayland"];}
        {_args = ["GBM_BACKEND" "nvidia-drm"];}
        {_args = ["__GLX_VENDOR_LIBRARY_NAME" "nvidia"];}
      ];
      # Top left corner is 0x0 is x and y. increasing y means physically a lower position.                                                                                                      │
      monitor = [
        {
          output = "DP-6";
          mode = "1920x1080@60";
          position = "6480x1679";
          scale = 1;
        }
        {
          output = "DP-5";
          mode = "1920x1080@60";
          position = "6480x2759";
          scale = 1;
        }
        {
          output = "DP-4";
          mode = "3840x2160@144";
          position = "4320x0";
          scale = 1;
          transform = 1;
          vrr = 1;
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
        # NOTE: DP-1 is not a real monitor on this host (monitors: DP-6/DP-5/DP-4,
        # and DP-4 is driven by mpvpaper); set `monitor` to DP-5/DP-6 to display it.
        wallpaper = [
          {
            monitor = "DP-1";
            path = "/home/${global_const.username}/acapulco_wallpaper_2.jxl";
          }
        ];
      };
    };
  };
}
