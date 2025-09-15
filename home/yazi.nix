{...}: {
  programs.yazi = {
    enable = true;
    settings = {
      log.enable = true;
      opener = {
        edit = [
          {
            run = "hx $0";
            block = true;
          }
        ];
        image = [
          {
            run = "gthumb $@";
            block = true;
          }
        ];
        play = [
          {
            run = "mpv \"$@\"";
            block = true;
          }
        ];
        document = [
          {
            run = "zathura $@";
            block = true;
          }
        ];
      };
      open = {
        rules = [
          {
            name = "*.ARW";
            use = "image";
          }
          {
            name = "*.jpg";
            use = "image";
          }
          {
            name = "*.png";
            use = "image";
          }
          {
            name = "*.webm";
            use = "play";
          }
          {
            name = "*.mp4";
            use = "play";
          }
          {
            name = "*.pdf";
            use = "document";
          }
          {
            name = "*.flac";
            use = "musikcube";
          }
        ];
      };
    };
  };
}
