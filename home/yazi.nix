{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y"; # New behaviour
    settings = {
      log.enable = true;
      opener = {
        edit = [
          {
            run = ''${pkgs.helix}/bin/hx "$@"'';
            block = true;
          }
        ];
        image = [
          {
            run = ''${pkgs.viu}/bin/viu "$@" && sleep 10'';
            block = true;
          }
        ];
        mpv = [
          {
            run = ''${pkgs.mpv}/bin/mpv "$@"'';
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
            run = ''${pkgs.zathura}/bin/zathura "$@"'';
            desc = "Open PDF";
          }
        ];
      };
      open = {
        rules = [
          ##### Images #####
          {
            url = "*.ARW";
            use = "image";
          }
          {
            url = "*.jpg";
            use = "image";
          }
          {
            url = "*.jpeg";
            use = "image";
          }
          {
            url = "*.png";
            use = "image";
          }
          ##### Video #####
          {
            url = "*.webm";
            use = "mpv";
          }
          {
            url = "*.mp4";
            use = "mpv";
          }
          {
            mime = "application/pdf";
            use = ["pdf"];
          }
          ##### Music #####
          {
            url = "*.flac";
            use = "music";
          }
          {
            url = "*.mp3";
            use = "music";
          }
        ];
      };
    };
  };
}
