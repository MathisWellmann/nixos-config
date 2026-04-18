{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y"; # New behaviour
    settings = {
      log.enable = true;
      opener = {
        edit = [
          {
            run = "${pkgs.helix}/bin/hx $0";
            block = true;
          }
        ];
        image = [
          {
            run = "${pkgs.viu}/bin/viu $@ && sleep 10";
            block = true;
          }
        ];
        mpv = [
          {
            run = "${pkgs.mpv}/bin/mpv \"$@\"";
            block = true;
          }
        ];
        music = [
          {
            run = ''${pkgs.moc}/bin/mocp "$@"'';
            block = true;
          }
        ];
        pdf = [
          {
            run = "${pkgs.zathura}/bin/zathura \"$@\"";
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
