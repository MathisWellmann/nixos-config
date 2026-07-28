{pkgs, ...}: {
  home.packages = with pkgs; [
    tinymist # Typst markup language with `.typ` file extension
    codebook
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
      };
      language = [
        {
          name = "rust";
          language-servers = ["rust-analyzer" "codebook" "scls"];
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
      theme = "catppuccin_frappe"; # Dark
      # theme = "base16_terminal"; # Transparent
      # theme = "onelight"; # Light
      keys.normal = {
        "f" = "file_picker";
        "l" = "move_visual_line_up";
        "w" = "move_visual_line_down";
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
