_: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y"; # New behaviour
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
        pdf = [
          {
            run = "zathura \"$@\"";
            desc = "Open PDF";
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
            mime = "application/pdf";
            use = ["pdf"];
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
