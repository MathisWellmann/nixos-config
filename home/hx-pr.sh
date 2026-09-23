# hx-pr — review a Gitea/Forgejo pull request in Helix with git-diff highlighting.
#
# usage: hx-pr <pr-number> [base-branch]
#   Run inside a git working tree of the target repository.
#   Base defaults to the remote's default branch (falls back to "main").
#
# Gitea/Forgejo expose pull requests as git refs (refs/pull/<N>/head),
# just like GitHub does. This script:
#   1. fetches refs/pull/<N>/head (and the base branch)
#   2. creates a throwaway linked worktree checked out at the base branch
#   3. applies the PR as *uncommitted* working-tree changes
#   4. opens helix in that worktree — Helix's built-in git decoration then
#      highlights the PR diff against HEAD, the file picker navigates the
#      real tree, ;g;f jumps between changed files, and LSP still works.
#
# The main checkout is never touched. After reviewing, clean up with the
# commands printed at the end.

set -euo pipefail

pr="${1:-}"
case "$pr" in
  "" | *[!0-9]*) echo "usage: hx-pr <pr-number> [base-branch]" >&2; exit 2 ;;
esac
base="${2:-}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "error: not inside a git work tree" >&2; exit 1; }

if [ -z "$base" ]; then
  base="$(git ls-remote --symref origin HEAD 2>/dev/null \
    | awk '/^ref:/{print $2; exit}' | sed 's@^refs/heads/@@')"
  base="${base:-main}"
fi

echo "→ fetching PR #$pr and base branch '$base' from origin..."
git fetch origin "$base"
# Fetch the PR ref on its own so FETCH_HEAD resolves to it, then pin the
# SHA: FETCH_HEAD is a file in the main repo's .git dir and does not
# resolve from inside a linked worktree.
git fetch origin "refs/pull/$pr/head"
prsha="$(git rev-parse FETCH_HEAD)"

# Review against the freshly fetched remote branch — that is what the PR
# would merge into. Fall back to a local branch of that name if the remote
# tracking ref is missing (e.g. unusual remote setups).
if git show-ref --verify --quiet "refs/remotes/origin/$base"; then
  baseref="origin/$base"
else
  baseref="$base"
fi

branch="review/pr-$pr"
wt_dir="${TMPDIR:-/tmp}/hx-pr-$pr"

# Clean up a previous review of this same PR so re-runs don't collide.
for d in "$wt_dir".*; do
  [ -d "$d" ] && git worktree remove --force "$d" 2>/dev/null || true
done
git worktree prune 2>/dev/null || true
git branch -D "$branch" 2>/dev/null || true

wt="$(mktemp -d "${wt_dir}.XXXXXX")"
git worktree add -b "$branch" "$wt" "$baseref"

cd "$wt"
difffile="$(mktemp "${wt_dir}.diff.XXXXXX")"
trap 'rm -f "$difffile"' EXIT
git diff "$baseref"...$prsha > "$difffile"

echo "→ applying PR on top of $baseref as uncommitted changes..."
if [ -s "$difffile" ]; then
  if ! git apply --3way "$difffile"; then
    echo "! 3-way apply did not go through; falling back to a merge (conflicts stay as markers)"
    git reset -q --hard
    git merge --no-commit --no-ff $prsha || true
  fi
  # merge may have staged the result — unstage so the changes remain in the
  # worktree, which is what Helix decorates (worktree vs HEAD)
  git reset -q
else
  echo "note: no changes between $baseref and the PR head (already merged or empty PR)"
fi

echo
echo "PR #$pr  (head: $(git rev-parse --short $prsha)) on top of $baseref"
echo "worktree: $wt"
echo "cleanup : git worktree remove --force '$wt' && git branch -D $branch"
echo
exec hx .
