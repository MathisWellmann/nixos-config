# google/ax (https://github.com/google/ax): the task API on top of Agent
# Substrate. See docs/ax_stack_todo.md (Phase 3).
#
# Same shape as pkgs/agent-substrate.nix: upstream Go binaries via
# buildGoModule, one layered image per in-cluster component, OCI layouts so
# the image digests are known at build time (`refs`), and a push script that
# pushes from those layouts so the registry digests match. `nix build .#ax`
# gives the `ax` CLI.
#
# Bump: change `rev`, refresh `hash` with
#   nix run nixpkgs#nix-prefetch-github -- google ax --rev <sha>
# then rebuild once to get the new `vendorHash` from the error message
# (ax does not vendor its deps, unlike substrate).
{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  dockerTools,
  cacert,
  tzdata,
  bashInteractive,
  coreutils,
  gnugrep,
  gnused,
  findutils,
  gawk,
  gnutar,
  gzip,
  git,
  curl,
  openssh,
  procps,
  writeShellApplication,
  runCommand,
  skopeo,
  jq,
  registry ? "de-msa2:2999/mathiswellmann",
}: let
  rev = "d8ed0fe38bceb7842d3c47817d53d16ccdfcb601";
  version = "0-unstable-2026-09-19";

  src = fetchFromGitHub {
    owner = "google";
    repo = "ax";
    inherit rev;
    hash = "sha256-mGSQ4QsYLdeKDtVMBODCulqQQ0Ze0NjeADPhB6edaYU=";
  };

  ax = buildGo127Module {
    pname = "ax";
    inherit version src;
    vendorHash = "sha256-iC/X6Bg1M7Pn3dT1zWs2YxuPfgl9ZKNEYQsBisIQguY=";
    subPackages = ["cmd/ax" "cmd/ax-server" "cmd/ax-controller" "cmd/ax-task-runner"];
    # Upstream hardcodes its GCR task-runner image as the default for tasks
    # without `spec.image`; this makes it overridable with
    # AX_DEFAULT_TASK_IMAGE on the controller (env/ax.nix sets it to the
    # digest-pinned runner built here). Candidate for upstreaming.
    patches = [./default-task-image-env.patch];
    env.CGO_ENABLED = 0;
    ldflags = ["-s" "-w"];
    doCheck = false;
    meta = {
      description = "AX: agent task API on Agent Substrate";
      homepage = "https://github.com/google/ax";
      license = lib.licenses.asl20;
      mainProgram = "ax";
    };
  };

  tag = builtins.substring 0 12 rev;

  # Fleet CA in the bundle: the controller talks to ate-api-server with the
  # Substrate CA it mounts, but the task runner clones from
  # https://forgejo.k3s.lan and any sandboxed tool may call the fleet's
  # *.k3s.lan services.
  ca-bundle = cacert.override {
    extraCertificateFiles = [../../modules/k3s-lan-ca.crt];
  };

  # Control-plane images: static binary at ko's /ko-app/<name> path, /tmp,
  # nothing else (upstream base is chainguard/static).
  mkStaticImage = name:
    dockerTools.buildLayeredImage {
      name = "${registry}/${name}";
      inherit tag;
      contents = [ca-bundle tzdata];
      extraCommands = ''
        mkdir -p ko-app
        ln -s ${ax}/bin/${name} ko-app/${name}
        mkdir -m 1777 tmp
      '';
      config = {
        Entrypoint = ["/ko-app/${name}"];
        Env = ["SSL_CERT_FILE=${ca-bundle}/etc/ssl/certs/ca-bundle.crt"];
      };
    };

  # The sandbox image every Task runs in (Dockerfile.task-runner upstream:
  # python:3.12-slim + git/curl/ssh/procps/bash + `pip install
  # google-antigravity`). The Antigravity agent is only used for
  # `workspaces[].goal`, which this fleet does not use (no Gemini key, see
  # docs/ax_stack_todo.md Phase 0), so no Python here; Phase 5 adds an image
  # with dsh/pi. Paths the runner and ax hardcode: `/usr/local/bin/ax-task-runner`
  # (DefaultGuestCommand), `/workspace` (durable volume mount), `git` and
  # `ssh` on PATH, `/bin/sh` for Task commands. Runs as root inside gVisor.
  taskRunnerImage = dockerTools.buildLayeredImage {
    name = "${registry}/ax-task-runner";
    inherit tag;
    contents = [
      ca-bundle
      tzdata
      bashInteractive
      coreutils
      gnugrep
      gnused
      findutils
      gawk
      gnutar
      gzip
      git
      curl
      openssh
      procps
      dockerTools.usrBinEnv
      dockerTools.binSh
      dockerTools.fakeNss
    ];
    extraCommands = ''
      mkdir -p usr/local/bin workspace root
      ln -s ${ax}/bin/ax-task-runner usr/local/bin/ax-task-runner
      mkdir -m 1777 tmp
    '';
    config = {
      Entrypoint = ["/usr/local/bin/ax-task-runner"];
      WorkingDir = "/workspace";
      Env = [
        "PATH=/usr/local/bin:/usr/bin:/bin"
        "HOME=/root"
        "SSL_CERT_FILE=${ca-bundle}/etc/ssl/certs/ca-bundle.crt"
        "GIT_SSL_CAINFO=${ca-bundle}/etc/ssl/certs/ca-bundle.crt"
      ];
    };
  };

  images = {
    ax-server = mkStaticImage "ax-server";
    ax-controller = mkStaticImage "ax-controller";
    ax-task-runner = taskRunnerImage;
  };
  imageNames = lib.attrNames images;

  # See pkgs/agent-substrate.nix: digest known at build time, pushed from
  # the same layout so the registry digest is identical.
  ociImages = lib.genAttrs imageNames (name:
    runCommand "${name}-oci" {nativeBuildInputs = [skopeo jq];} ''
      export HOME=$TMPDIR
      skopeo --tmpdir $TMPDIR copy --insecure-policy --format oci \
        docker-archive:${images.${name}} oci:$out:${tag}
      jq -r '.manifests[0].digest' $out/index.json > $out/digest
    '');
  digests = lib.mapAttrs (_: oci: lib.removeSuffix "\n" (builtins.readFile "${oci}/digest")) ociImages;
  # Control-plane refs are pulled by the kubelet (plain-HTTP mirror in
  # modules/k3s_registries.nix); the task runner is pulled by atelet, which
  # needs the HTTPS ingress path (see pkgs/agent-substrate.nix).
  refs =
    lib.mapAttrs (name: digest: "${registry}/${name}:${tag}@${digest}") digests
    // {
      ax-task-runner = "forgejo.k3s.lan/mathiswellmann/ax-task-runner@${digests.ax-task-runner}";
    };

  push = writeShellApplication {
    name = "push-ax-images";
    runtimeInputs = [skopeo];
    text = ''
      set -x
      ${lib.concatMapStringsSep "\n" (name: ''
          skopeo copy --dest-tls-verify=false \
            oci:${ociImages.${name}}:${tag} \
            docker://${registry}/${name}:${tag}
        '')
        imageNames}
      set +x
      echo "pushed digests (must match pkgs/ax refs):"
      ${lib.concatMapStringsSep "\n" (name: ''
          echo "  ${name} $(skopeo inspect --tls-verify=false docker://${registry}/${name}:${tag} | grep -m1 '"Digest"' | cut -d'"' -f4)  expected ${digests.${name}}"
        '')
        imageNames}
    '';
  };
in {
  inherit ax images ociImages digests refs push tag registry src;
}
