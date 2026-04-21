_: {
  programs = {
    kitty = {
      enable = true;
      settings = {
        confirm_os_window_close = -1;
        shell = "nu";
        background_opacity = 0.7;
        wheel_scroll_multiplier = 1;
        repaint_delay = 7; # 7ms is 144hz
        # Essentially vsync
        sync_to_monitor = "no";
      };
      font = {
        name = "Terminus";
        size = 13;
      };
    };
    alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.8;
        font = {
          size = 16.0;
          # normal.family = "HackNerdFont";
          normal.family = "Terminus";
          # normal.family = "DepartureMonoNerdFont";
        };
        terminal.shell.program = "nu";
      };
    };
    ghostty = {
      enable = true;
      settings = {
        font-size = 16;
        mouse-scroll-multiplier = "1.0";
        background-opacity = 0.8;
        background-blur = true;
        keybind = [
          "ctrl+h=goto_split:left"
          "ctrl+l=goto_split:right"
        ];
        font-family = "Maple Mono NF";
      };
    };
  };
}
