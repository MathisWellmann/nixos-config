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
          merge-editor = "mergiraf";
        };
        snapshot.max-new-file-size = "10MB";
        git.write-change-id-header = true;
        templates.draft_commit_description = ''
          concat(
            coalesce(description, default_commit_description, "\n"),
            surround(
              "\nJJ: This commit contains the following changes:\n", "",
              indent("JJ:     ", diff.stat(72)),
            ),
            "\nJJ: ignore-rest\n",
            diff.git(),
          )
        '';
      };
    };
  };
}
