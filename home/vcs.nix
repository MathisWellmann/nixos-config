_: let
  name = "MathisWellmann";
  email = "wellmannmathis@gmail.com";
  global_const = import ../global_constants.nix;
in {
  programs = {
    git = {
      enable = true;
      signing.format = "openpgp";
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
        revset-aliases = {
          "closest_pushable(to)" = {
            definition = ''heads(::to & mutable() & ~description(exact:"") & (~empty() | merges()))'';
            doc = "Closest non-empty, described commit at or behind to, which can be pushed";
          };
          "stack_heads()" = {
            definition = "stack_heads(@)";
            doc = "Newest mutable commits at or ahead of the working copy";
          };
          "stack_heads(to)" = {
            definition = "heads(mutable() & to::)";
            doc = "Newest mutable commits at or ahead of to";
          };
          "stack_top()" = {
            definition = "stack_top(@)";
            doc = "Newest mutable, single commit at or ahead of the working copy";
          };
          "stack_top(to)" = {
            definition = "exactly(stack_heads(to), 1)";
            doc = "Newest mutable, single commit at or ahead of to";
          };
          "stack_bottom()" = {
            definition = "stack_bottom(@)";
            doc = "Oldest mutable commits at or behind the working copy";
          };
          "stack_bottom(to)" = {
            definition = "roots(mutable() & ::to)";
            doc = "Oldest mutable commits at or behind to";
          };
          "stack()" = {
            definition = "stack(@)";
            doc = "Full stack containing the working copy, from its bottom to its top";
          };
          "stack(to)" = {
            definition = "stack_bottom(to)::stack_top(to)";
            doc = "Full stack containing to, from stack_bottom(to) to stack_top(to)";
          };
          "substack()" = {
            definition = "substack(@)";
            doc = "Stack from its bottom through the working copy";
          };
          "substack(to)" = {
            definition = "stack_bottom(to)::to";
            doc = "Stack containing to, from stack_bottom(to) through to";
          };
          "tree()" = {
            definition = "tree(@)";
            doc = "Full tree (all stacks) containing the working copy";
          };
          "tree(to)" = {
            definition = "reachable(to, mutable())";
            doc = "Full tree (all stacks) containing to";
          };
        };
        aliases = {
          # Moves the closest bookmark to the change that can actually be pushed.
          tug = {
            definition = ["bookmark" "move" "--from" "heads(::@ & bookmarks())" "--to" "closest_pushable(@)"];
            doc = "Move the closest bookmark to the closest pushable change";
          };
          move-to = {
            definition = [
              "util"
              "exec"
              "--"
              "bash"
              "-c"
              ''
                cd "''${JJ_WORKSPACE_ROOT:-.}"
                revset=$1
                shift
                edit=$(jj config get ui.movement.edit 2>/dev/null || echo false)
                args=()
                for a in "$@"; do
                  case $a in
                    -e|--edit)    edit=true ;;
                    -n|--no-edit) edit=false ;;
                    *)            args+=("$a") ;;
                  esac
                done
                if $edit; then verb=edit; else verb=new; fi
                exec jj "$verb" "''${args[@]}" "$revset"
              ''
              "jj-move"
            ];
            doc = "Move to a revset: new child of it, or edit it with -e";
          };
          bottom = {
            definition = ["move-to" "stack_bottom()"];
            doc = "Move to the bottom of the current stack, stack_bottom()";
          };
          top = {
            definition = ["move-to" "stack_top()"];
            doc = "Move to the top of the current stack, stack_top()";
          };
          sb = {
            definition = ["stack-bookmarks"];
            doc = "Shorthand for stack-bookmarks";
          };
          stack-bookmarks = {
            definition = [
              "--config"
              "revsets.log=substack()"
              "log"
              "--no-graph"
              "--reversed"
              "-T"
              ''if(local_bookmarks, local_bookmarks.map(|b| b.name()).join(" ") ++ " ", "")''
            ];
            doc = "Local bookmark names in substack(@), oldest first, space-separated";
          };
        };
        signing = {
          behaviour = "own";
          backend = "ssh";
          key = "/home/${global_const.username}/.ssh/id_ed25519.pub";
        };
      };
    };
  };
}
