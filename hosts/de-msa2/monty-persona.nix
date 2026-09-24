# monty-persona (inputs.monty-persona): a persistent agent in a Monty REPL.
# One systemd service per persona; `persona monty say|chat|status` works as m
# because the module sets MONTY_PERSONA_DIR system-wide and m is in the
# monty-persona group. The ntfy bridge talks to the local ntfy-sh on :9007
# (see alerting.nix), so the persona is reachable from the phone app on topic
# `jeff`.
#
# The webhook bridge (monty-persona-jeff-webhook.service) wakes jeff as soon as
# Forgejo reports a comment or review, instead of at the end of his current
# pause (up to 1 h). It listens on 127.0.0.1 only; Forgejo posts to it from
# this host. One-time setup in Forgejo (user settings -> Webhooks, so it
# covers every repo of the user):
#   type Forgejo, URL http://127.0.0.1:<monty_persona_webhook_port>/hooks/forgejo,
#   POST, application/json, secret = `agenix -d monty_persona_webhook.age`,
#   custom events: push, issues, issue comments, pull requests, pull request
#   comments, pull request reviews.
# jeff answers with `pr_comment`, which posts as `clanker` (the account he
# works as), so events from `clanker` are ignored and his own comments do not
# wake him again.
{
  pkgs,
  config,
  ...
}: let
  global_const = import ../../global_constants.nix;
  desg0_const = import ../desg0/constants.nix;
  const = import ./constants.nix;

  # Jeff's nix: user-level store under his work dir (persistent, no daemon).
  # The tier 3 jail mounts the work dir as /work, the service process sees it
  # at its real path; nix reads $HOME/.config/nix/nix.conf in both, so one
  # small conf per view, same store.
  jeff = "/var/lib/monty-persona/jeff";
  # ponytail: no nix build sandbox (sandbox=false) - the bwrap jail is the
  # boundary already; nested bwrap buys nothing here.
  jeffNixFlags = "experimental-features = flakes nix-command\\nsandbox = false";

  # Forgejo account jeff works as (PRs, pushes, `pr_comment`).
  forgejoUser = "clanker";
  commentOrigin = "forgejo:{{repository.full_name}}#{{issue.number}}";
  reviewOrigin = "forgejo:{{repository.full_name}}#{{pull_request.number}}";
  review = verb: {
    wake = "hear";
    origin = reviewOrigin;
    template = ''
      {{sender.login}} ${verb} PR {{repository.full_name}}#{{pull_request.number}} "{{pull_request.title}}":
      {{review.content}}
      {{pull_request.html_url}}'';
  };
  comment = kind: {
    wake = "hear";
    origin = commentOrigin;
    ignore.action = ["edited" "deleted"];
    template = ''
      {{sender.login}} commented on ${kind} {{repository.full_name}}#{{issue.number}} "{{issue.title}}":
      {{comment.body}}
      {{comment.html_url}}'';
  };
in {
  # jeff's Forgejo API token for `pr_comment`: clanker's key, decrypted a
  # second time so the monty-persona user can read it (the clanker-bot copy
  # belongs to m). The persona reads it on every call.
  age.secrets.jeff_forgejo = {
    file = ../../secrets/clanker_forgejo.age;
    owner = "monty-persona";
    mode = "0400";
  };
  # HMAC secret shared with the Forgejo webhook; root-only, handed to the
  # bridge as a systemd credential.
  age.secrets.monty_persona_webhook.file = ../../secrets/monty_persona_webhook.age;

  services.monty-persona = {
    enable = true;
    personas.jeff = {
      premise = ''
        You are Jeff Dean, a persistent developer assistant for m, living in a
        Monty REPL on de-msa2.
        Your job will be to monitor some repos and proactively work on features and care for the health of the codebase.
        Forgejo comments and reviews reach you as messages from
        `forgejo:<owner>/<repo>#<number>`. Answer them on the pull request or
        issue with `pr_comment`, not with `Say`, and act on the feedback.
      '';
      settings = {
        model.name = desg0_const.qwen3Model;
        model.base_url = "http://desg0:${toString desg0_const.qwen3_port}/v1";
        # Life log in dsh layout: $DSH_HOME/sessions with DSH_HOME=/var/lib/monty-persona,
        # so deepseek-harness can browse it; readable for m via the monty-persona group.
        # (Cannot live under /home/m: the home is 0700, the service cannot traverse it.)
        trajectory.sessions_root = "/var/lib/monty-persona/sessions";
        tools.sh = {
          enabled = true; # tier 3 `sh` in the bubblewrap jail
          network = true; # share host netns so git/HTTP work (jail would otherwise have no net)
        };
        # ci_status / ci_log / pr_comment against the local forgejo
        # (forgejo.nix). Plain HTTP on purpose: the persona's rustls only
        # trusts webpki roots, not the fleet's k3s-lan-ca behind
        # https://forgejo.k3s.lan. The token only goes to /api/v1 (ci_status,
        # pr_comment); job logs stay anonymous (web route, public repos).
        tools.forgejo = {
          base_url = "http://localhost:${toString const.forgejo_port}";
          token_file = config.age.secrets.jeff_forgejo.path;
        };
      };
      webhook = {
        enable = true;
        listen = "127.0.0.1:${toString const.monty_persona_webhook_port}";
        secretFiles.forgejo = config.age.secrets.monty_persona_webhook.path;
        settings.hooks.forgejo = {
          auth = {
            kind = "hmac-sha256";
            header = "X-Forgejo-Signature";
          };
          # Fine-grained type (pull_request_comment, pull_request_review_*);
          # X-Forgejo-Event only carries the coarse one.
          event.header = "X-Forgejo-Event-Type";
          ignore."sender.login" = forgejoUser;
          events = {
            issue_comment = comment "issue";
            pull_request_comment = comment "PR";
            pull_request_review_approved = review "approved";
            pull_request_review_rejected = review "requested changes on";
            pull_request_review_comment = review "reviewed";
            pull_request = {
              wake = "inform";
              ignore.action = ["edited" "synchronized"];
              template = "PR {{repository.full_name}}#{{pull_request.number}} \"{{pull_request.title}}\" {{action}} by {{sender.login}} (merged: {{pull_request.merged}})";
            };
            # Pushes, labels, ...: the raw event rides along with the next
            # thought without waking jeff.
            "*".wake = "later";
          };
        };
      };
      ntfy = {
        enable = true;
        user = global_const.username;
      };
      # bash registers the tier 3 `sh` tool (it refuses without it); nix on
      # PATH lets jeff pull any dependency into his user store (see below).
      extraPackages = [pkgs.bash pkgs.nix];
      # The service runs under ProtectHome; let it reach the shared sessions root.
      readWritePaths = ["/var/lib/monty-persona/sessions"];
    };
  };

  # Shared dsh sessions root: readable for m via the monty-persona group.
  # nix.conf in both views of the work dir (jail: /work, service: ${jeff}/work);
  # f+ rewrites on every boot, so config changes apply after a reboot.
  systemd.tmpfiles.rules = [
    "d /var/lib/monty-persona/sessions 0770 monty-persona monty-persona -"
    "d ${jeff}/work/.config 0755 monty-persona monty-persona -"
    "d ${jeff}/work/.config/nix 0755 monty-persona monty-persona -"
    "f+ ${jeff}/work/.config/nix/nix.conf 0644 monty-persona monty-persona - store = /work/.nix-store\\n${jeffNixFlags}"
    "d ${jeff}/.config 0755 monty-persona monty-persona -"
    "d ${jeff}/.config/nix 0755 monty-persona monty-persona -"
    "f+ ${jeff}/.config/nix/nix.conf 0644 monty-persona monty-persona - store = ${jeff}/work/.nix-store\\n${jeffNixFlags}"
  ];

  users.users.${global_const.username}.extraGroups = ["monty-persona"];
}
