# List all repos starred (liked) by a user on Hugging Face.
#
# The `hf` CLI has no command for this yet; the functionality only exists in
# the `huggingface_hub` Python API via `list_liked_repos`, so we shell out to
# a small Python script backed by the nixpkgs `huggingface-hub` package.
#
# Usage:
#   nix run .#hf-stars                    # liked repos of the logged-in user
#   nix run .#hf-stars -- julien-c        # liked repos of a specific user
{pkgs, ...}: let
  py = pkgs.python3.withPackages (ps: [ps.huggingface-hub]);

  script = pkgs.writeText "hf-stars.py" ''
    import sys

    from huggingface_hub import list_liked_repos
    from huggingface_hub.errors import LocalTokenNotFoundError

    # Treat a missing *or empty* argument as "the logged-in user".
    user = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else None

    try:
        likes = list_liked_repos(user)
    except LocalTokenNotFoundError:
        sys.exit(
            "error: no user given and not logged in.\n"
            "       Pass a username (hf-stars <user>) or run `hf auth login`."
        )

    print(f"User: {likes.user}")
    print(f"Models:   {len(likes.models)}")
    for m in likes.models:
        print(f"  model   {m}")
    print(f"Datasets: {len(likes.datasets)}")
    for d in likes.datasets:
        print(f"  dataset {d}")
    print(f"Spaces:   {len(likes.spaces)}")
    for s in likes.spaces:
        print(f"  space   {s}")
  '';
in
  pkgs.writeShellScriptBin "hf-stars" ''
    set -euo pipefail

    exec ${py}/bin/python ${script} "$@"
  ''
