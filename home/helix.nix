_: {
  programs.helix = {
    enable = true;
    languages = {
      language-server.rust-analyzer = {
        config = {cargo = {features = "all";};};
      };
      language-server.codebook = {
        command = "codebook-lsp";
        args = ["serve"];
      };
      language-server.lsp-ai = let
        max_context = 128000;
      in {
        command = "lsp-ai";
        environment = {LSP_AI_LOG = "debug";};
        timeout = 60;
        config = {
          memory.file_store = {};
          models.qwen3coder = {
            type = "ollama";
            model = "qwen3-coder:30b";
          };
          completion = {
            model = "qwen3-coder";
            parameters = {
              inherit max_context;
              options.num_predict = 32;
            };
          };
          chat = [
            {
              trigger = "!C";
              action_display_name = "qwen3-coder:30b";
              model = "qwen3coder";
              parameters = {
                inherit max_context;
                max_tokens = 4096;
                messages = [
                  {
                    role = "system";
                    content = "You are a rust code assistant chatbot. You will give expertly responses and follow best rust coding practices.";
                  }
                ];
              };
            }
          ];
        };
      };
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer" "codebook" "lsp-ai"];
        }
      ];
    };
    settings = {
      theme = "gruvbox-material"; # Dark
      # theme = "curzon"; # Dark
      # theme = "onelight";
      keys.normal = {
        "f" = "file_picker";
        # "," = "move_visual_line_up";
        # "." = "move_visual_line_down";
        "a" = "move_char_left";
        "}" = "move_char_right";
      };
      editor = {
        scroll-lines = 1;
        cursorline = true;
        auto-save = false;
        completion-trigger-len = 1;
        true-color = true;
        auto-pairs = true;
        rulers = [120];
        idle-timeout = 0;
        bufferline = "always";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        lsp = {
          display-messages = true;
          display-inlay-hints = false;
        };
        statusline = {
          left = ["mode" "spinner" "file-name" "file-type" "total-line-numbers" "file-encoding"];
          center = [];
          right = ["selections" "primary-selection-length" "position" "position-percentage" "spacer" "diagnostics" "workspace-diagnostics" "version-control"];
        };
        # Minimum severity to show a diagnostic after the end of a line.
        end-of-line-diagnostics = "hint";
        inline-diagnostics = {
          cursor-line = "error";
        };
        file-picker.hidden = false; # Don't hide hidden files
      };
    };
  };
}
