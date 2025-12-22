_: {
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
            run = "viu $@ && sleep 10";
            block = true;
          }
        ];
        mpv = [
          {
            run = "mpv \"$@\"";
            block = true;
          }
        ];
        music = [
          {
            run = ''mocp "$@"'';
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
          ##### Images #####
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
          ##### Video #####
          {
            name = "*.webm";
            use = "mpv";
          }
          {
            name = "*.mp4";
            use = "mpv";
          }
          {
            name = "*.pdf";
            use = "document";
          }
          ##### Music #####
          {
            name = "*.flac";
            use = "music";
          }
          {
            name = "*.mp3";
            use = "music";
          }
        ];
      };
    };
  };
}
