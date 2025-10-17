{...}: let
  me = "MathisWellmann";
  email = "wellmannmathis@gmail.com";
in {
  programs = {
    git = {
      enable = true;
      userName = "${me}";
      userEmail = "${email}";
      extraConfig = {
        push = {autoSetupRemote = true;};
        init = {
          defaultBranch = "main";
        };
        core.editor = "hx";
        pull.rebase = true;
        credential.helper = "store";
      };
    };
    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "${me}";
          email = "${email}";
        };
        ui = {
          editor = "hx";
          pager = "delta";
          paginate = "never";
          diff-formatter = ["difft" "--color=always" "$left" "$right"];
        };
        snapshot.max-new-file-size = "10MB";
        git.write-change-id-header = true;
      };
    };
  };
}
