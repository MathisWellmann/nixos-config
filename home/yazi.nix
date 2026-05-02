{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y"; # New behaviour
    settings = {
      log.enable = true;
      opener = {
        edit = [
          {
            run = ''${pkgs.helix}/bin/hx "%s"'';
            block = true;
          }
        ];
        image = [
          {
            run = ''${pkgs.viu}/bin/viu "%s" && sleep 10'';
            block = true;
          }
        ];
        mpv = [
          {
            run = ''${pkgs.mpv}/bin/mpv "%s"'';
            block = true;
          }
        ];
        music = [
          {
            run = ''${pkgs.moc}/bin/mocp "%s"'';
            block = true;
          }
        ];
        pdf = [
          {
            run = ''${pkgs.zathura}/bin/zathura "%s"'';
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
