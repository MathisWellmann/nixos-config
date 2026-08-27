{pkgs, ...}: {
  # ponytail: yazi needs `file` on PATH for mime-based open rules (video/*, pdf)
  home.packages = [pkgs.file];

  programs.yazi = {
    enable = true;
    shellWrapperName = "y"; # New behaviour
    settings = {
      log.enable = true;
      opener = {
        edit = [
          {
            run = ''${pkgs.helix}/bin/hx %s'';
            block = true;
          }
        ];
        image = [
          {
            run = ''${pkgs.viu}/bin/viu %s && sleep 10'';
            block = true;
          }
        ];
        mpv = [
          {
            run = ''${pkgs.mpv}/bin/mpv %s'';
            block = true;
          }
        ];
        music = [
          {
            run = ''${pkgs.moc}/bin/mocp %s'';
            block = true;
          }
        ];
        pdf = [
          {
            run = ''${pkgs.zathura}/bin/zathura %s'';
            desc = "Open PDF";
          }
        ];
      };
      open = {
        # ponytail: `prepend_rules` keeps yazi's preset rules (dirs, text, archives,
        # and the `url = "*"` fallback). Using `rules` would replace them outright,
        # leaving anything unmatched silently unopenable.
        prepend_rules = [
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
            mime = "video/*"; # covers mp4, webm, mkv, mov, ...
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
