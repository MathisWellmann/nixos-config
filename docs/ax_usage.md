# Working with ax: deploy and operate agent tasks

This guide explains how to write, deploy, watch and clean up ax Tasks on the
k3s fleet. The README section "Sandboxed agent tasks" gives a short overview.
For build notes and open items, see [`ax_stack_todo.md`](ax_stack_todo.md).

Versions: ax `d8ed0fe38bce`, Agent Substrate `dc1f263076d1`. Both are
pre-alpha, so the API can change when you upgrade.

## 1. How it works

```
ax CLI ──h2c──> ax-server (ax-system) ──> Redis (Tasks, Workspaces, Gateways)
                      │
                ax-controller ──> Substrate (ate-system)
                                     │
                     ActorTemplate + Actor ──> gVisor sandbox on desg0 / de-n5
                                                   │
                                     /workspace (durable) + your command
```

- A **Task** is one sandboxed process. It runs `spec.command` in a container
  image, with one or more git repos cloned into `/workspace`.
- ax keeps its objects in **Redis**, not in Kubernetes. They are not CRDs, so
  ArgoCD does not deploy them and `kubectl get` does not show them. Use the
  `ax` CLI or `nix run .#ax_apply`.
- Substrate runs each Task as an **actor** in a gVisor sandbox. Workers run
  only on the Zen-4 nodes (`desg0`, `de-n5`).
- **Suspend** writes a snapshot to rustfs (S3) and frees the worker.
  **Resume** restores the snapshot, possibly on a different node.

## 2. Access

Every Home Manager host has the `ax` and `kubectl-ate` CLIs.

| Host | Setup | What works |
| --- | --- | --- |
| tensorbook | `AX_SERVER=ax.k3s.lan:80` (set in nushell; export it in bash) | `apply`, `get`, `describe`, `watch`, `suspend`, `resume`, `delete` |
| de-msa2, meshify (as user `m`) | fleet kubeconfig; ax port-forwards by itself | all commands, including `ax ssh` and `kubectl ate` |

Check the connection:

```sh
ax ctx          # active context and AX connection
ax get tasks
```

Rules:

- Do not run `ax` or `ax_apply` with `sudo`. sudo keeps `HOME`, so ax leaves
  root-owned `~/.kube` and `~/.ax` behind, and `ax` then fails for `m`.
- `ax ssh` and `kubectl ate` always tunnel to `atenet-router`. They need a
  kubeconfig even when `AX_SERVER` is set. Use them on de-msa2 or meshify.
- On meshify, use `KUBECONFIG=~/.kube/k3s.yaml ax ...`. The default
  `~/.kube/config` points to the local k3d cluster.
- The error `dial tcp [::1]:8080: connection refused` means that ax found no
  `AX_SERVER` and no usable kubeconfig.

## 3. Objects

All object files are in `manifests/ax/`. Use one file per object. Name the
file `<kind>-<name>.yaml`.

| Kind | Purpose | Shared? |
| --- | --- | --- |
| `Gateway` | egress allowlist for a Task | yes, `gateway-*.yaml` |
| `Workspace` | git repos to clone into `/workspace` | yes, `workspace-*.yaml` |
| `Model` | LLM for the Workspace `goal` bootstrap (Gemini only, not used) | yes, `model-*.yaml` |
| `Task` | one sandboxed run | no, one-off, `task-*.yaml` |

Existing shared objects:

- `Gateway lan-llm`: SGLang on desg0 (`192.168.0.13:8000`), Forgejo,
  GitHub.
- `Workspace monty-persona`: `forgejo.k3s.lan/MathisWellmann/monty-persona`,
  branch `main`.

### 3.1 Workspace

```yaml
apiVersion: ax.io/v1alpha1
kind: Workspace
metadata:
  name: my-repo
  atespace: default
spec:
  git:
    - name: origin
      repo: "https://forgejo.k3s.lan/MathisWellmann/my-repo.git"
      branch: "main"
      dir: "."      # clone into the workspace root (the Task working dir)
      depth: 1      # optional shallow clone
```

- Without `dir: "."`, ax clones to `/workspace/<workspace>/<repo name>`.
- Pods resolve only `forgejo.k3s.lan` of the `*.k3s.lan` names (through
  `coredns-custom`). For other LAN services, use the IP address.
- The runner image contains the fleet CA, so HTTPS to `forgejo.k3s.lan`
  works. Fallback: `http://192.168.0.14:2999/<owner>/<repo>.git`.
- Do not set `mcp`, `skills` or `goal`. They need Google registries and
  Gemini.

### 3.2 Gateway

```yaml
apiVersion: ax.io/v1alpha1
kind: Gateway
metadata:
  name: lan-llm
  atespace: default
spec:
  egress:
    allowlist:
      hosts:
        - host: "192.168.0.13/32"   # write bare IPs as CIDRs
          port: 8000
        - host: "forgejo.k3s.lan"
          port: 443
```

**Warning:** the fleet does not enforce the allowlist. ax drops `port`, and
Substrate enforces egress only through an egress gateway, which is not
deployed. Sandbox egress is allow-all. Keep the Gateway correct for the day
enforcement starts, but do not rely on it for security.

### 3.3 Task

```yaml
apiVersion: ax.io/v1alpha1
kind: Task
metadata:
  name: summarize-my-repo      # unique in the atespace
  atespace: default
spec:
  # image: forgejo.k3s.lan/mathiswellmann/<name>@sha256:...  (optional)
  command:
    - bash
    - -c
    - |
      set -x
      pi -p --no-session --thinking low \
        "Summarize this repository into /workspace/summary.md" \
        2>&1 | tee /workspace/pi.log
  env:
    - name: FOO
      value: "bar"
  resources:
    requests: { cpu: "1", memory: "2Gi" }
    limits:   { cpu: "4", memory: "8Gi" }
  workspaces:
    - name: my-repo            # the first entry is the working directory
  gateway:
    name: lan-llm
  debug: true                  # enables `ax ssh`
  # suspend: true              # create the Task suspended
```

Task fields:

| Field | Meaning |
| --- | --- |
| `image` | Container image. If you omit it, ax uses the Nix-built runner (`AX_DEFAULT_TASK_IMAGE`). A custom image must be pinned by digest. |
| `command` | argv of the process. Use `bash -c` for scripts. |
| `env` | Plain `name`/`value` pairs. There are no secret references: values are stored in clear text in Redis. |
| `resources` | CPU and memory requests and limits. |
| `workspaces` | Workspaces to mount under `/workspace`. `path` is optional. |
| `gateway` | Egress policy (see 3.2). |
| `debug` | Starts the guest services for `ax ssh`. Set it to `true` unless you have a reason not to. |

The command runs in the first workspace, with the runner's environment plus
`spec.env` and `AX_METADATA_URL` (the runner's local metadata server).
| `suspend` | Desired state. `ax suspend` and `ax resume` change it. |

## 4. The default runner image

A Task without `image` runs `ax-task-runner` (`pkgs/ax/default.nix`). It
contains:

- bash, coreutils, grep, sed, awk, find, tar, gzip, procps
- git, curl, openssh, the fleet CA
- [`pi`](https://pi.dev), set up for Qwen3.8 on desg0 through the `sglang`
  provider (`/root/.pi/agent/{models,settings}.json`)

Environment: `OPENAI_BASE_URL=http://192.168.0.13:8000/v1`, `PI_OFFLINE=1`.
Do not set `OPENAI_API_KEY`: pi then offers its full OpenAI catalog instead
of the local model.

To run pi without a human:

```sh
pi -p --no-session --thinking low "<prompt>"
```

The image has **no language toolchains**: no nix, cargo or python. An agent
in the default image can read and edit code, but it cannot build or test it.
For that, build a custom image (section 7).

## 5. Deploy a Task

### 5.1 Apply the shared objects

Do this once, and again after ax loses its Redis data:

```sh
nix run .#ax_apply
```

The script applies `gateway-*`, `model-*` and `workspace-*` from
`manifests/ax/`, in that order. Note that it applies a **store copy** of the
directory: commit or `git add` new files first, or pass them as arguments.

### 5.2 Apply the Task

```sh
nix run .#ax_apply -- manifests/ax/task-summarize-my-repo.yaml
# or
ax apply -f manifests/ax/task-summarize-my-repo.yaml
```

### 5.3 Watch it

```sh
ax get tasks
ax describe task summarize-my-repo
ax watch task summarize-my-repo
```

Expected conditions: the ActorTemplate is created, the actor resumes on a
worker, then `WorkspaceReady`. After that the phase is `Running`.

**`Running` is the last phase.** ax has no `Succeeded` or `Failed` phase for
a finished command. When the command exits, the runner logs the exit code
and keeps the sandbox up for inspection until you suspend or delete the
Task. To find out whether the command finished, look at its output.

### 5.4 Get the results

```sh
ax ssh summarize-my-repo -- cat /workspace/pi.log /workspace/summary.md
ax ssh summarize-my-repo            # interactive shell
```

For automation, do not depend on `ax ssh`. Let the Task deliver its result
itself, for example:

- push a branch to Forgejo,
- post a comment through the Forgejo API,
- upload a file to rustfs,
- write a marker file such as `/workspace/.done` with the exit code.

### 5.5 Clean up

```sh
ax delete task summarize-my-repo
```

This also deletes the Substrate actor and its ActorTemplates.

## 6. Suspend and resume

```sh
ax suspend task summarize-my-repo   # snapshot to rustfs, worker freed
ax resume task summarize-my-repo    # restore, maybe on another node
```

What survives a suspend:

| Kept | Lost |
| --- | --- |
| `/workspace` (durable volume) | `/tmp`, running processes, shell history |

Suspend sends SIGTERM to the command's process group (SIGKILL after a grace
period). Resume restores `/workspace` and starts a new `ax-task-runner`. The
runner skips the git clone (a marker file shows that the workspace is
already set up) and then **starts `command` again from the beginning**. So
write long commands to be **restartable**:

```bash
set -euo pipefail
state=/workspace/.state
mkdir -p "$state"
[[ -f $state/step1 ]] || { do_step1; touch "$state/step1"; }
[[ -f $state/step2 ]] || { do_step2; touch "$state/step2"; }
```

Also:

- The first request after a resume can time out. Retry it.
- Snapshots are bound to CPU features. The `gvisor` WorkerPool excludes
  de-msa2 (Zen 5), so snapshots move only between Zen-4 nodes.

## 7. Custom task images

Use a custom image when the Task must build or test code.

1. Build the image with Nix (`dockerTools.buildLayeredImage`). Use
   `taskRunnerImage` in `pkgs/ax/default.nix` as a template. The image must
   contain:
   - `/usr/local/bin/ax-task-runner` (the entrypoint that ax expects),
   - `git` and `ssh` on `PATH`,
   - `/bin/sh`,
   - a `/tmp` directory with mode `1777`,
   - the fleet CA bundle.
2. Push it to Forgejo, then take the digest from the push output.
3. Refer to the image by digest through the Forgejo hostname:

   ```yaml
   image: forgejo.k3s.lan/mathiswellmann/ax-runner-rust@sha256:<digest>
   ```

   atelet pulls with go-containerregistry. It uses plain HTTP only for
   localhost and RFC1918 addresses, and Forgejo redirects token auth to
   `https://forgejo.k3s.lan`. A tag without a digest is rejected.

To change the default image for all Tasks, update the runner in
`pkgs/ax/`, run `skopeo login --tls-verify=false de-msa2:2999`, then
`nix run .#ax-push-images`, and push `main`. **Push the images before you
push `main`**, otherwise ArgoCD rolls out digests that are not in the
registry yet. ArgoCD polls every 3 minutes. To sync immediately (on
de-msa2):

```sh
kubectl -n argocd annotate applications.argoproj.io ax \
  argocd.argoproj.io/refresh=hard --overwrite
```

## 8. Patterns

### Many Tasks from one template

Generate the files, then apply them. Give each Task a unique name:

```bash
for input in nixpkgs home-manager agenix; do
  sed "s/@INPUT@/$input/g" manifests/ax/task-bump.yaml.in \
    > "/tmp/task-bump-$input.yaml"
  ax apply -f "/tmp/task-bump-$input.yaml"
done
```

All Tasks share one SGLang endpoint. Parallel Tasks queue on the GPU, so
fan out to only a few Tasks at a time (3 to 5).

### Push results to Forgejo

```bash
git switch -c "agent/my-task"
pi -p --no-session "<prompt>"
git -c user.name=ax-agent -c user.email=ax@k3s.lan commit -am "agent: <summary>"
git push "https://ax-agent:${FORGEJO_TOKEN}@forgejo.k3s.lan/<owner>/<repo>.git" HEAD
```

`env` values are stored in clear text in Redis, and egress is allow-all. So
give Tasks only tokens with a small scope: one repo, and the least
permissions the job needs.

### Human approval between steps

1. The Task writes `/workspace/plan.md` and stops.
2. `ax suspend task X`. The Task now uses no worker resources.
3. Read the plan (`ax ssh X -- cat /workspace/plan.md` before the suspend,
   or have the Task push the plan).
4. `ax resume task X`. The restartable command (section 6) continues with
   the next step.

## 9. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `dial tcp [::1]:8080: connection refused` | no `AX_SERVER` and no kubeconfig | `export AX_SERVER=ax.k3s.lan:80` |
| `404 page not found` from `ax.k3s.lan` | traefik talks HTTP/1.1 to ax-server | the `serversscheme: h2c` annotation must be on the Service (`env/ax.nix`) |
| `ax ssh` fails with `AX_SERVER` set | `ax ssh` needs a kubeconfig | run it on de-msa2 or meshify as `m` |
| `ax ssh` fails on a running Task | `debug` is not set | set `debug: true`, then delete and re-apply the Task |
| A re-applied Task runs the old image or old files | Substrate resumed the old actor with its old template and snapshot | `ax delete task X`, then apply again |
| "must be pinned by digest" | `image` has a tag only | use `@sha256:...` |
| Sandbox dies with `waiting for sandbox to start: EOF` | the image has no `/tmp` | add `/tmp` (mode `1777`) to the image |
| Actor stuck in `RESUMING` | `runsc restore` failed (CPU mismatch or a bad snapshot) | it clears when the worker pod goes away; check the WorkerPool node selector |
| Tasks lost after a Redis restart | Redis data lost | `nix run .#ax_apply`, then re-apply Tasks; delete orphaned actors (below) |

Look at the Substrate side (on de-msa2 or meshify):

```sh
kubectl ate get actors -a default
kubectl ate get actor-template -a default
kubectl -n ax-system logs deploy/ax-controller
kubectl -n ate-system get pods -o wide
```

## 10. Limitations

- Egress is allow-all (section 3.2).
- `ax.k3s.lan` has no authentication. Everyone on the LAN or tailnet can
  create Tasks.
- Task `env` has no secret references.
- There is no end state for a finished command (section 5.3).
- `goal`, `Model`, MCP and skills work only with Gemini and Google
  registries.
- Sandboxes have no GPU access.
- Only `/workspace` survives a suspend.
