{pkgs, ...}: let
  jq = "${pkgs.jq}/bin/jq";
  curl = "${pkgs.curl}/bin/curl";
  de-msa2_const = import ./../hosts/de-msa2/constants.nix;
  forgejo_url = "http://localhost:${toString de-msa2_const.forgejo_port}";
in
  pkgs.writeShellScriptBin "list-flake-apps" ''
    set -euo pipefail

    ############################################
    # CONFIG
    ############################################

    # GitHub
    GITHUB_API="https://api.github.com"
    GITHUB_TOKEN="$(< /etc/secrets/github_token)"

    # Forgejo
    FORGEJO_API="${forgejo_url}/api/v1"
    FORGEJO_TOKEN="$(< /etc/secrets/forgejo_mirrors)"
    FORGEJO_OWNER="mirrors"

    # Mirror settings
    VISIBILITY="public"
    MIRROR_INTERVAL="24h"
    REPO_PREFIX="github"     # github-OWNER-REPO

    gh_api() {
      ${curl} -fsSL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" $@
    }

    fj_api() {
      ${curl} -fsSL -H "Authorization: token $FORGEJO_TOKEN" "$@"
    }

    get_starred_repos() {
      local page=0
      while :; do
        local result
        result="$(gh_api "$GITHUB_API/user/starred?per_page=100&page=$page")"
        echo "$result"
        if [[ "$(${jq} length <<<"$result")" -eq 0 ]]; then
          break
        fi
        ((page++))
      done
    }

    forgejo_repo_exists() {
      local repo="$1"
      fj_api -o /dev/null -w "%{http_code}" \
        "$FORGEJO_API/repos/$FORGEJO_OWNER/$repo" \
        | grep -q '^200$'
    }

    create_mirror() {
      local owner="$1"
      local name="$2"
      local clone_url="$3"

      local repo_name="$REPO_PREFIX-$owner-$name"

      if forgejo_repo_exists "$repo_name"; then
        echo "✓ Exists: $repo_name"
        return
      fi

      echo "→ Creating mirror: $repo_name"

      ${jq} -n \
        --arg clone_addr "$clone_url" \
        --arg repo_name "$repo_name" \
        --arg interval "$MIRROR_INTERVAL" \
        --argjson private "$([[ "$VISIBILITY" == "private" ]] && echo true || echo false)" \
        '{
          clone_addr: $clone_addr,
          repo_name: $repo_name,
          mirror: true,
          private: $private,
          interval: $interval
        }' \
      | fj_api \
          -H "Content-Type: application/json" \
          -X POST \
          -d @- \
          "$FORGEJO_API/repos/migrate"
    }

    ############################################
    # MAIN
    ############################################

    echo "Syncing GitHub starred repos → Forgejo"
    echo

    get_starred_repos \
    | ${jq} -r '.[] | [.owner.login, .name, .clone_url] | @tsv' \
    | while IFS=$'\t' read -r owner name clone_url; do
        create_mirror "$owner" "$name" "$clone_url"
      done

    echo
    echo "Done."
  ''
