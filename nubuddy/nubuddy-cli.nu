# nubuddy-cli.nu — run nubuddy as a one-shot script (no REPL needed)
#
# Run from the nubuddy/ directory (nushell's `source` needs a literal path):
#   nu ./nubuddy-cli.nu "your prompt"
#   nu ./nubuddy-cli.nu "do a thing" --yes
#
# Nushell auto-invokes a `main` def with the script's arguments.

source ./nubuddy.nu

def main [
  ...prompt: string,
  --yes,
] {
  let text = ($prompt | str join " ")
  if $text == "" {
    print 'usage: nu ./nubuddy-cli.nu "your prompt" [--yes]'
    return
  }
  if $yes {
    ask $text --yes
  } else {
    ask $text
  }
}
