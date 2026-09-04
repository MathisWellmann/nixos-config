# ============================================================================
# nubuddy.nu — an intelligent nushell, in the spirit of
# "IPython is all you need" (nathancooper.io, 2026-08-10)
#
# Usage (inside a nushell REPL):
#   source nubuddy.nu
#   ask "what am I working on?"
#   ask "sum the two newest numbers in data.csv" --yes
#
# Or as a script (from this directory):
#   nu nubuddy-cli.nu "your prompt"
#
# Environment:
#   NU_BUDDY_BASE_URL  OpenAI-compatible endpoint, e.g. http://desg0:8000/v1
#   NU_BUDDY_API_KEY   bearer token
#   NU_BUDDY_MODEL     model slug
#   NU_BUDDY_DIR       where state/transcript live (default: ~/.config/nushell/nubuddy)
#
# What the LLM can do:
#   nu_exec    run nushell in your working directory; persistent state record __S__
#   nu_history read your shell history (persisted across sessions)
#
# Safety (the "safeish" part — advisory, like safecmd in the blog post):
#   - hard-blocked: :( process-substitution, `plugin add`
#   - asks you before running: rm / mv / kill / any external (^cmd)
#   - use --yes to skip confirmation (don't)
# ============================================================================

def nubuddy-safe [script: string] {
  let s = $script | str lowercase
  if ($s | str contains ":(") {
    return { ok: false, reason: ":( process-substitution is blocked", confirm: false }
  }
  if ($s | str contains "plugin add") {
    return { ok: false, reason: "plugin add is blocked", confirm: false }
  }
  # statement starts we want to double-check with the human
  let stmts = (
    $s
    | lines
    | each { |l| $l | split row ";" }
    | flatten
    | each { |st| $st | str trim }
    | where { |st| $st != "" }
  )
  let firsts = (
    $stmts
    | each { |st| $st | split row " " | where { $in != null and (($in | str trim) != "") } | first }
    | where { $in != null }
  )
  let dangerous = ["rm", "mv", "kill"]
  let needs = (
    $firsts
    | any { |t| ($t in $dangerous) or ($t | str starts-with "^") }
  )
  { ok: true, reason: "", confirm: $needs }
}

def nubuddy-exec [script: string, S, dir: string, yes: bool] {
  if not ($dir | path exists) { mkdir $dir }
  let safe = nubuddy-safe $script
  if not $safe.ok {
    return { out: $"blocked: ($safe.reason)", S: $S, ran: false }
  }
  if $safe.confirm and not $yes {
    print $"⚠  nubuddy wants to run: ($script | str trim | str replace --all (char nl) ' ↵ ')"
    let a = (try { input "run anyway? [y/N] " } catch { "" })
    if not (($a | str lowercase | str trim) | str starts-with "y") {
      return { out: "user declined to run this command", S: $S, ran: false }
    }
  }

  let sfile = (($dir | path join "state.json"))
  # NOTE: no try/catch wrapper — nushell forbids assigning to variables declared
  # in an outer scope, so a try{} around the LLM code would break `__S__.x = v`.
  # Parse and runtime errors surface via the child's exit code + stderr instead.
  let stateline = "($__S__ | to nuon) | print"
  let markerline = "'NUBUDY-OK' | print"
  let composed = $"mut __S__ = ($S | to nuon)
($script)
($stateline)
($markerline)"
  let tmpf = (($dir | path join "last-run.nu"))
  $composed | save --force $tmpf

  let c = (^$nu.current-exe $tmpf | complete)

  if $c.exit_code != 0 {
    let err0 = ($c.stderr | str trim)
    let err = (if ($err0 | str length) > 800 { ($err0 | str substring 0..799) + "..." } else { $err0 })
    return {
      out: ("ERROR (exit code " + ($c.exit_code | into string) + ")\n" + $err)
      S: $S
      ran: true
    }
  }

  let lines = ($c.stdout | str trim | lines)
  let n = ($lines | length)
  let has_marker = ($n >= 2 and (($lines | last) | str trim) == "NUBUDY-OK")
  let stateline = (if $has_marker { ($lines | last 2 | first | str trim) } else { "" })
  let S2 = (if ($stateline | str length) > 0 { try { $stateline | from nuon } catch { $S } } else { $S })
  let out_lines = (if $has_marker { $lines | first ($n - 2) } else { $lines })
  $S2 | save --force $sfile

  # keep the transcript (what the LLM itself ran) bounded
  let tfile = (($dir | path join "transcript.jsonl"))
  let tline = (
    {
      ts: (date now | format date "%Y-%m-%d %H:%M:%S")
      script: $script
      out: ($out_lines | str join "\n")
    }
    | to json --raw
  )
  let prev = (try { $tfile | open --raw } catch { "" })
  let kept = (($prev + $tline + "\n") | lines | last 30 | str join "\n")
  ($kept + "\n") | save --force $tfile

  {
    out: (($out_lines | str join "\n") | str trim | default -e "(no output)")
    S: $S2
    ran: true
  }
}

def nubuddy-llm [msgs, base: string, key: string, model: string] {
  let tools = [
    {
      type: "function"
      function: {
        name: "nu_exec"
        description: "Execute nushell code in the user's working directory. Persistent state: the mutable record $__S__ is loaded before your code and re-serialized after it. To store something, update a field of it, e.g. $__S__.my_var = 42; to read it back later, use $__S__.my_var. The code runs as a script, not a REPL: bare pipeline values are NOT displayed, so end every pipeline whose result you want to see with `| print` (e.g. `ls | get name | print`). Variables must be declared with let/mut; only $__S__ survives between calls. Returns the script's stdout; errors come back in the tool result."
        parameters: {
          type: "object"
          properties: { script: { type: "string", description: "nushell code to run" } }
          required: [script]
        }
      }
    }
    {
      type: "function"
      function: {
        name: "nu_history"
        description: "Return the user's nushell command history (commands they typed, persisted across sessions in a plain-text file)."
        parameters: {
          type: "object"
          properties: {
            n: { type: "integer", description: "how many recent commands to return (default 10)" }
          }
          required: []
        }
      }
    }
  ]
  let messages = ($msgs | each { |m| $m | from json })
  let body = {
    model: $model
    messages: $messages
    max_tokens: 8192
    tools: $tools
  }
  if ($env.NU_BUDDY_DEBUG? != null) {
    ($body | to json) | save --force ($env.NU_BUDDY_DEBUG | path join "req.json")
  }
  let resp = (
    http post ($base + "/chat/completions") ($body | to json)
    -H { authorization: $"bearer ($key)", "content-type": "application/json" }
  )
  let m = $resp.choices.0.message
  { content: ($m.content? | default ""), tool_calls: ($m.tool_calls? | default []) }
}

def ask [
  prompt: string,
  --yes,
  --context: int = 10,
  --steps: int = 10,
] {
  let base = ($env.NU_BUDDY_BASE_URL? | default "http://127.0.0.1:8000/v1" | str trim --right --char "/")
  let key = $env.NU_BUDDY_API_KEY?
  let model = ($env.NU_BUDDY_MODEL? | default "gpt-4o-mini")
  if $key == null {
    print "nubuddy: set NU_BUDDY_API_KEY (and NU_BUDDY_BASE_URL / NU_BUDDY_MODEL)"
    return
  }

  let dir = ($env.NU_BUDDY_DIR | default (($env.HOME | path join ".config/nushell/nubuddy")))
  if not ($dir | path exists) { mkdir $dir }

  let sfile = (($dir | path join "state.json"))
  mut S = (try { open $sfile } catch { { } })

  let tfile = (($dir | path join "transcript.jsonl"))
  let transcript = ((try { $tfile | open --raw } catch { "" }) | lines | last 30 | str join "\n")

  let hist = (try { history | last $context | get command | str join "\n" } catch { "" })

  let sysprompt = (
    "You are nubuddy, an AI that lives inside the user's nushell shell.
Tools: nu_exec runs nushell code in the user's working directory (the mutable record $__S__ persists between calls — store surviving variables as $__S__.field = value); nu_history returns recent user-typed shell commands.
nu_exec runs a script, not a REPL: only `print`ed values appear in the result, so pipe to `| print`.
Be concise, use markdown, prefer read-only commands, and never be destructive without the user asking."
  )
  let usermsg = $"<shell-context>
recent user commands from shell history \(oldest first\):
($hist)
</shell-context>
<transcript>
your own previous executions:
($transcript)
</transcript>
<user-request>($prompt)</user-request>"

  # nushell has no mutation across blocks, so the whole chat loop threads its
  # state (message list + persistent __S__ record) through reduce as a record.
  # messages are kept as JSON strings: nushell list `+` refuses to concat
  # records with different columns, so we append raw JSON instead
  let acc0 = {
    msgs: [
      ({ role: "system", content: $sysprompt } | to json),
      ({ role: "user", content: $usermsg } | to json),
    ]
    S: $S
    done: false
  }

  let acc = (0..$steps | reduce -f $acc0 { |i, st|
    if $st.done { $st } else {
      let r = nubuddy-llm $st.msgs $base $key $model
      let tcs = $r.tool_calls
      if ($tcs | length) == 0 {
        print $r.content
        { msgs: $st.msgs, S: $st.S, done: true }
      } else {
        let msgs2 = ($st.msgs | append ({ role: "assistant", content: $r.content, tool_calls: $tcs } | to json))
        let tr = ($tcs | reduce -f { msgs: $msgs2, S: $st.S } { |tc, tst|
          let name = $tc.function.name
          let args = (try { $tc.function.arguments | from json } catch { { } })
          let res = (if $name == "nu_exec" {
            let scr = ($args.script | default "")
            print $"⚙  nu_exec: ($scr | str trim | str replace --all (char nl) ' ↵ ')"
            let e = nubuddy-exec $scr $tst.S $dir $yes
            { S: $e.S, out: $e.out }
          } else if $name == "nu_history" {
            let out = (history | last ($args.n | default 10) | get command | str join "\n")
            { S: $tst.S, out: $out }
          } else {
            { S: $tst.S, out: $"unknown tool: ($name)" }
          })
          let msgs3 = ($tst.msgs | append ({ role: "tool", tool_call_id: $tc.id, content: $res.out } | to json))
          { msgs: $msgs3, S: $res.S }
        })
        { msgs: $tr.msgs, S: $tr.S, done: false }
      }
    }
  })

  if not $acc.done {
    print "nubuddy: step limit reached before a final answer"
  }
}
