_: {
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "codebook"
      "docker-compose"
      "marksman"
      "nickel"
      "nu"
    ];
    userSettings = {
      features = {
        copilot = false;
      };
      telemetry = {
        metrics = false;
      };
      vim_mode = false;
      helix_mode = true;
      ui_font_size = 18;
      buffer_font_size = 18;
      lsp = {
        rust-analyzer.binary.path = "rust-analyzer";
        pylsp.binary.path = "pylsp";
      };
      diagnostics.inline = {
        enabled = true;
        max_severity = null;
      };
    };
  };
}
