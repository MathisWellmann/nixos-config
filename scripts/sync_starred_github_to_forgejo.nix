{pkgs, ...}: let
  jq = "${pkgs.jq}/bin/jq";
  curl = "${pkgs.curl}/bin/curl";
  de-msa2_const = import ./../hosts/de-msa2/constants.nix {};
  forgejo_url = "http://localhost:${toString de-msa2_const.forgejo_port}";
in
  pkgs.writeShellScriptBin "sync-starred-github-to-forgejo" ''
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
    MIRROR_INTERVAL="8h"
    REPO_PREFIX="github"     # github-OWNER-REPO

    gh_api() {
      ${curl} -fsSL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$@"
    }

    fj_api() {
      # Handle HTTP status codes ourselves so expected 404s stay quiet and
      # failed migrations can be cleaned up before processing the next repo.
      ${curl} -sSL -H "Authorization: token $FORGEJO_TOKEN" "$@"
    }

    get_starred_repos() {
      local page=1
      while :; do
        local result
        result="$(gh_api "$GITHUB_API/user/starred?per_page=100&page=$page")"
        echo "$result"
        if [[ "$(${jq} length <<<"$result")" -eq 0 ]]; then
          break
        fi
        ((++page))
      done
    }

    create_mirror() {
      local owner="$1"
      local name="$2"
      local clone_url="$3"
      local repo_name="$REPO_PREFIX-$owner-$name"
      local status

      if ! status="$(fj_api -o "$tmp_dir/response" -w "%{http_code}" \
        "$FORGEJO_API/repos/$FORGEJO_OWNER/$repo_name")"; then
        echo "✗ Could not query Forgejo for $repo_name" >&2
        return 1
      fi

      case "$status" in
        200)
          # A timed-out migration leaves an empty mirror whose first update was
          # never completed. Remove it so this run can retry the migration.
          if ${jq} -e '.mirror and .empty and (.mirror_updated | startswith("0001-"))' \
            "$tmp_dir/response" > /dev/null; then
            echo "⚠ Removing incomplete mirror: $repo_name" >&2
            status="$(fj_api -o "$tmp_dir/response" -w "%{http_code}" \
              -X DELETE "$FORGEJO_API/repos/$FORGEJO_OWNER/$repo_name")"
            if [[ "$status" != 204 ]]; then
              echo "✗ Could not remove incomplete $repo_name (HTTP $status):" >&2
              cat "$tmp_dir/response" >&2
              return 1
            fi
          else
            echo "✓ Exists: $repo_name"
            return
          fi
          ;;
        404) ;;
        *)
          echo "✗ Forgejo returned HTTP $status while checking $repo_name:" >&2
          cat "$tmp_dir/response" >&2
          return 1
          ;;
      esac

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
        }' > "$tmp_dir/request"

      if ! status="$(fj_api -o "$tmp_dir/response" -w "%{http_code}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d @"$tmp_dir/request" \
        "$FORGEJO_API/repos/migrate")"; then
        echo "✗ Could not create $repo_name: Forgejo request failed" >&2
        return 1
      fi

      if [[ "$status" == 201 ]]; then
        echo "✓ Created: $repo_name"
        return
      fi

      echo "✗ Could not create $repo_name (HTTP $status):" >&2
      cat "$tmp_dir/response" >&2
      echo >&2

      # Forgejo can leave a broken, empty repository after a migration timeout.
      # It did not exist above, so deleting it here is safe and permits retries.
      local cleanup_status
      if cleanup_status="$(fj_api -o "$tmp_dir/cleanup-response" -w "%{http_code}" \
        -X DELETE "$FORGEJO_API/repos/$FORGEJO_OWNER/$repo_name")"; then
        case "$cleanup_status" in
          204) echo "  Removed partial repository so it can be retried." >&2 ;;
          404) ;;
          *)
            echo "  Cleanup failed with HTTP $cleanup_status:" >&2
            cat "$tmp_dir/cleanup-response" >&2
            ;;
        esac
      else
        echo "  Cleanup request failed; check the repository manually." >&2
      fi
      return 1
    }

    ############################################
    # MAIN
    ############################################

    echo "Syncing GitHub starred repos → Forgejo"
    echo

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    get_starred_repos > "$tmp_dir/starred.json"
    ${jq} -r '.[] | [.owner.login, .name, .clone_url] | @tsv' \
      "$tmp_dir/starred.json" > "$tmp_dir/repos.tsv"

    failures=0
    while IFS=$'\t' read -r owner name clone_url; do
      if ! create_mirror "$owner" "$name" "$clone_url"; then
        failures=$((failures + 1))
      fi
    done < "$tmp_dir/repos.tsv"

    echo
    if ((failures)); then
      echo "Finished with $failures failed mirror(s)." >&2
      exit 1
    fi
    echo "Done."
  ''
