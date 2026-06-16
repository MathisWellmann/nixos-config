{pkgs, ...}: {
  home.packages = with pkgs; [
    tinymist # Typst markup language with `.typ` file extension
    codebook
    lsp-ai # language server that serves as a backend for AI-powered functionality
    simple-completion-language-server
  ];
  programs.helix = {
    enable = true;
    languages = {
      language-server = {
        rust-analyzer = {
          config = {cargo = {features = "all";};};
        };
        codebook = {
          command = "codebook-lsp";
          args = ["serve"];
        };
        # provides easy unicode support for all those fancy symbols
        scls = {
          command = "simple-completion-language-server";
          config = {
            feature_words = false;
            feature_unicode_input = true;
          };
        };
        # tinymist for Typst documents, enabling live preview along the way.
        tinymist = {
          command = "tinymist";
          config = {
            preview.background.enabled = true;
            preview.background.args = [
              "--data-plane-host=127.0.0.1:23635"
              "--invert-colors=never"
              "--open"
            ];
          };
        };
        lsp-ai = let
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
      };
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer" "codebook" "lsp-ai" "scls"];
        }
        {
          name = "markdown";
          language-servers = ["scls"];
        }
        {
          name = "typst";
          language-servers = ["tinymist"];
        }
      ];
    };
    settings = {
      # theme = "gruber-darker"; # Dark
      # theme = "curzon"; # Dark
      theme = "base16_terminal"; # Transparent
      # theme = "onelight"; # Light
      keys.normal = {
        "f" = "file_picker";
        "l" = "move_visual_line_up";
        "w" = "move_visual_line_down";
        "m" = "move_char_left";
        # "n" = "move_char_right";
        # "N" = "move_next_word_start";
        "M" = "move_prev_word_start";
      };
      editor = {
        scroll-lines = 3;
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
