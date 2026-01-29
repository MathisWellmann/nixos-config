_: let
  name = "MathisWellmann";
  email = "wellmannmathis@gmail.com";
  global_const = import ../global_constants.nix;
in {
  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          inherit name email;
        };
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
          name = "${name}";
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
        revset-aliases."closest_pushable(to)" = ''heads(::to & mutable() & ~description(exact:"") & (~empty() | merges()))'';
        # Moves the closest bookmark to the change that can actually be pushed.
        aliases.tug = ["bookmark" "move" "--from" "heads(::@ & bookmarks())" "--to" "closest_pushable(@)"];
        signing = {
          behaviour = "own";
          backend = "ssh";
          key = "/home/${global_const.username}/.ssh/id_ed25519.pub";
        };
      };
    };
  };
}
