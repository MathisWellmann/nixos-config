# Agent Substrate (https://github.com/agent-substrate/substrate): the gVisor
# sandbox / suspend-resume runtime under google/ax. See docs/ax_stack_todo.md.
#
# Upstream builds its images with `ko`; we build the same static Go binaries
# with buildGoModule (the repo vendors its deps, so no vendorHash churn) and
# wrap each in a minimal layered image, the moral equivalent of ko's
# distroless-static base. `nix build .#agent-substrate` gives the binaries
# (incl. the `kubectl-ate` CLI); `.#agent-substrate-images` is a directory of
# OCI tarballs plus a `push` script that skopeo-copies them to the Forgejo
# registry with the exact tags the rendered manifests reference.
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
  skopeo,
  # Registry path the images are pushed to. Plain HTTP; k3s trusts it via
  # modules/k3s_registries.nix.
  registry ? "de-msa2:2999/mathiswellmann",
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

  substrate = buildGo127Module {
    pname = "agent-substrate";
    inherit version src;
    # Deps are vendored upstream (vendor/modules.txt); Go uses them as-is.
    vendorHash = null;
    subPackages = map (c: "cmd/${c}") components;
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

  mkImage = name:
    dockerTools.buildLayeredImage {
      name = "${registry}/${name}";
      inherit tag;
      contents = [cacert tzdata];
      config = {
        Entrypoint = ["${substrate}/bin/${name}"];
        Env = ["SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"];
      };
    };

  imageNames = lib.filter (c: c != "kubectl-ate") components;
  images = lib.genAttrs imageNames mkImage;

  push = writeShellApplication {
    name = "push-agent-substrate-images";
    runtimeInputs = [skopeo];
    text = ''
      # Registry auth: `skopeo login --tls-verify=false de-msa2:2999` once with a
      # Forgejo token (stored in ~/.config/containers/auth.json).
      set -x
      ${lib.concatMapStringsSep "\n" (name: ''
          skopeo copy --dest-tls-verify=false \
            docker-archive:${images.${name}} \
            docker://${registry}/${name}:${tag}
        '')
        imageNames}
    '';
  };
in {
  inherit substrate images push tag;
}
