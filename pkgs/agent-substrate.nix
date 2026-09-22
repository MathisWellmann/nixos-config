# Agent Substrate (https://github.com/agent-substrate/substrate): the gVisor
# sandbox / suspend-resume runtime under google/ax. See docs/ax_stack_todo.md.
#
# Upstream builds its images with `ko`; we build the same static Go binaries
# with buildGoModule (the repo vendors its deps, so no vendorHash churn) and
# wrap each in a minimal layered image, the moral equivalent of ko's
# distroless-static base. `nix build .#agent-substrate` gives the binaries
# (incl. the `kubectl-ate` CLI); `.#agent-substrate-push-images` skopeo-copies
# the images to the Forgejo registry. Manifests (env/substrate.nix) pin them
# by digest via `refs`, computed here at build time, so after any image change
# the push and the rendered manifests move together.
#
# Bump: change `rev`, refresh `hash` with
#   nix run nixpkgs#nix-prefetch-github -- agent-substrate substrate --rev <sha>
# and record the pair in docs/ax_stack_todo.md.
{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  dockerTools,
  cacert,
  tzdata,
  writeShellApplication,
  runCommand,
  skopeo,
  jq,
  # Registry path the images are pushed to. Plain HTTP; k3s trusts it via
  # modules/k3s_registries.nix.
  registry ? "de-msa2:2999/mathiswellmann",
  # Make ateom run `runsc -debug -debug-log <actor dir>/...` (upstream ships
  # the flags commented out). The sentry's boot log then lands under
  # /var/lib/ateom-gvisor/actors/<uid>/ on the node, the only way to see why
  # a sandbox died when `runsc create` reports just "waiting for sandbox to
  # start: EOF". Costs disk and some startup time; off unless debugging.
  debugRunsc ? false,
}: let
  rev = "dc1f263076d1575c0562c71d763edd0a0342fd68";
  version = "0-unstable-2026-09-21";

  src = fetchFromGitHub {
    owner = "agent-substrate";
    repo = "substrate";
    inherit rev;
    hash = "sha256-1sSBKk+dKlYG1y4h9zWUNrwNOJ5GHeg+dyNPqkq2tEE=";
  };

  # Every in-cluster component plus the operator CLI. ateom-microvm is left
  # out: it needs /dev/kvm workers and a glibc base, neither of which the
  # fleet's gvisor-only WorkerPools use.
  components = [
    "ateapi"
    "atecontroller"
    "atelet"
    "atenet"
    "ateom-gvisor"
    "podcertcontroller"
    "kubectl-ate"
  ];
  # Upstream's smoke-test actor (demos/counter): an HTTP counter whose
  # in-memory and on-disk counts must survive suspend/resume. Small, and the
  # only way to prove the gVisor + snapshot path end to end without ax.
  demos = ["counter"];

  substrate = buildGo127Module {
    pname = "agent-substrate";
    inherit version src;
    # Deps are vendored upstream (vendor/modules.txt); Go uses them as-is.
    vendorHash = null;
    subPackages = map (c: "cmd/${c}") components ++ map (d: "demos/${d}") demos;
    postPatch = lib.optionalString debugRunsc ''
      sed -i -E 's|^(\s*)// ("-debug",)$|\1\2|; s|^(\s*)// ("-debug-log", ateompath.RunscDebugLogDir.*)$|\1\2|' \
        cmd/ateom-gvisor/runsc.go
      grep -c '^\s*"-debug",' cmd/ateom-gvisor/runsc.go
    '';
    env.CGO_ENABLED = 0;
    ldflags = ["-s" "-w"];
    # Upstream runs e2e suites against a kind cluster; unit tests need network
    # and a fake apiserver, not worth the build time here.
    doCheck = false;
    meta = {
      description = "Agent Substrate: Kubernetes-native sandboxed actor runtime";
      homepage = "https://github.com/agent-substrate/substrate";
      license = lib.licenses.asl20;
      mainProgram = "kubectl-ate";
    };
  };

  # Tag = short rev so a manifest pin is unambiguous and a bump is a diff.
  tag = builtins.substring 0 12 rev;

  # atelet pulls actor images itself (go-containerregistry, HTTPS unless the
  # registry is localhost or an RFC1918 IP). Forgejo answers plain HTTP on
  # de-msa2:2999 but sends clients to its ROOT_URL for the auth token, so
  # actor images are referenced as forgejo.k3s.lan/... through the traefik
  # ingress instead; that cert is issued by the fleet CA, which the public
  # bundle does not carry. (Pods resolve forgejo.k3s.lan via the CoreDNS
  # hosts entry in env/substrate.nix.)
  ca-bundle = cacert.override {
    extraCertificateFiles = [../modules/k3s-lan-ca.crt];
  };

  # ko puts the binary at /ko-app/<name>; upstream manifests and demo
  # ActorTemplates hardcode that path in `command`, so keep it as a symlink.
  mkImage = name:
    dockerTools.buildLayeredImage {
      name = "${registry}/${name}";
      inherit tag;
      contents = [ca-bundle tzdata];
      # /tmp: ko's distroless-static base has it; buildLayeredImage does not.
      # runsc boot sets up the sentry's chroot at /tmp and dies without it
      # ("error setting up chroot: ... Open(/tmp): no such file or
      # directory"), which surfaces in ateom only as `runsc create` failing
      # with "waiting for sandbox to start: EOF".
      extraCommands = ''
        mkdir -p ko-app
        ln -s ${substrate}/bin/${name} ko-app/${name}
        mkdir -m 1777 tmp
      '';
      config = {
        Entrypoint = ["/ko-app/${name}"];
        Env = ["SSL_CERT_FILE=${ca-bundle}/etc/ssl/certs/ca-bundle.crt"];
      };
    };

  imageNames = lib.filter (c: c != "kubectl-ate") components ++ demos;
  images = lib.genAttrs imageNames mkImage;

  # OCI layout of each image, so its manifest digest is known at build time.
  # The tag is mutable (rebuilt images are re-pushed under it) and the
  # WorkerPool controller creates worker pods with the default pull policy,
  # so a tag alone leaves nodes running whatever they cached first. Pinning
  # by digest makes every image change a manifest diff. Pushing FROM this
  # layout (not the docker-archive) keeps the manifest bytes, hence the
  # digest, identical in the registry.
  ociImages = lib.genAttrs imageNames (name:
    runCommand "${name}-oci" {nativeBuildInputs = [skopeo jq];} ''
      # skopeo unpacks docker-archives under /var/tmp, absent in the sandbox.
      export HOME=$TMPDIR
      skopeo --tmpdir $TMPDIR copy --insecure-policy --format oci \
        docker-archive:${images.${name}} oci:$out:${tag}
      jq -r '.manifests[0].digest' $out/index.json > $out/digest
    '');
  # IFD: the digest is read from the build output.
  digests = lib.mapAttrs (_: oci: lib.removeSuffix "\n" (builtins.readFile "${oci}/digest")) ociImages;
  # Full pinned reference for manifests, `<registry>/<name>:<tag>@sha256:...`.
  refs = lib.mapAttrs (name: digest: "${registry}/${name}:${tag}@${digest}") digests;

  push = writeShellApplication {
    name = "push-agent-substrate-images";
    runtimeInputs = [skopeo];
    text = ''
      # Registry auth: `skopeo login --tls-verify=false de-msa2:2999` once with a
      # Forgejo token (stored in ~/.config/containers/auth.json).
      set -x
      ${lib.concatMapStringsSep "\n" (name: ''
          skopeo copy --dest-tls-verify=false \
            oci:${ociImages.${name}}:${tag} \
            docker://${registry}/${name}:${tag}
        '')
        imageNames}
      set +x
      echo "pushed digests (must match pkgs/agent-substrate.nix refs):"
      ${lib.concatMapStringsSep "\n" (name: ''
          echo "  ${name} $(skopeo inspect --tls-verify=false docker://${registry}/${name}:${tag} | grep -m1 '"Digest"' | cut -d'"' -f4)  expected ${digests.${name}}"
        '')
        imageNames}
    '';
  };
in {
  inherit substrate images ociImages digests refs push tag registry src;
}
