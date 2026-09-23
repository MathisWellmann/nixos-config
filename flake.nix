{
  description = "Nixos config flake";

  inputs = {
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    agenix.url = "github:ryantm/agenix";
    nox.url = "github:madsbv/nix-options-search";
    # Animated wallpaper daemon written in rust, because `mpvpaper` leaks memory.
    awww.url = "git+https://codeberg.org/LGFae/awww";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    llm-agents.url = "github:numtide/llm-agents.nix";
    autolith.url = "github:lambda-symbolics/autolith";
    forgecode.url = "github:tailcallhq/forgecode";
    kopuz.url = "github:temidaradev/kopuz";
    stochos.url = "github:museslabs/stochos";
    nixidy.url = "github:arnarg/nixidy";
    maki.url = "github:tontinton/maki";
    rustgrep.url = "git+https://radicle.dpc.pw/z3wPTYCEHukxHQNU2fQ2b3eASNw8a.git";
    # Helm charts packaged as nix derivations, used by nixidy applications.
    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Self-hosted on de-msa2's forgejo (hosts/de-msa2/forgejo.nix); the
    # `k3s.lan` name resolves over tailscale via modules/base_system.nix.
    monty-persona = {
      url = "git+https://forgejo.k3s.lan/MathisWellmann/monty-persona.git";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
  # some CUDA packages require like 250GB of RAM to compile from scratch, so use binary caches.
  # Run with `--accept-flake-config`. The fleet cache comes first so plain
  # `nix build` from a checkout hits it too (NixOS hosts already have it via
  # modules/base_system.nix).
  nixConfig = {
    extra-substituters = [
      "http://de-msa2:3019/nixos"
      "https://cache.nixos-cuda.org"
      "https://cache.numtide.com"
      "https://kopuz.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos:pPhlDMvdiF4HkyCuSODwk9Xc442dGLGA8+HqUxo23OI="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "kopuz.cachix.org-1:WXMpGpamblLUiJtcoxBxGGGGwIcWxGPJBUxarLiqWmw="
    ];
  };

  outputs = {
    self,
    nixpkgs-unstable,
    home-manager,
    hermes-agent,
    nixidy,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs-unstable {inherit system;};
    # google/ax, built once: the push script and the nixidy env (image digest
    # pins in manifests/prod/ax) must see the same derivation.
    axBundle = pkgs.callPackage ./pkgs/ax {
      inherit (inputs.llm-agents.packages.${system}) pi;
    };
    # Build a NixOS configuration for a host in `hosts/<name>/`.
    # `home-manager` is always wired in here so individual host
    # `configuration.nix` files don't each re-import it. `extraModules`
    # carries host-specific flake modules (agenix, sops, hermes-agent, ...).
    mkHost = name: extraModules:
      nixpkgs-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            ./hosts/${name}/configuration.nix
            home-manager.nixosModules.default
            {
              home-manager.useUserPackages = true;
              environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];
            }
          ]
          ++ extraModules;
      };
    treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
  in {
    nixidyEnvs."${system}" = nixidy.lib.mkEnvs {
      inherit pkgs;

      # Module argument for env/ax.nix.
      extraSpecialArgs = {inherit axBundle;};

      # Makes helm charts available to applications as the `charts` module argument.
      charts = inputs.nixhelm.chartsDerivations.${system};

      envs = {
        prod.modules = [./env/prod.nix];
      };
    };
    packages."${system}" = {
      # The nixidy CLI, e.g. `nix run .#nixidy -- switch .#prod`
      nixidy = nixidy.packages.${system}.default;

      # The Hugging Face `hf` CLI, e.g. `nix run .#hf -- download <repo>`
      hf = pkgs.callPackage ./pkgs/hf.nix {};

      # DeepSeek Harness agent CLI, e.g. `nix run .#deepseek-harness -- web`
      deepseek-harness = let
        dsh = inputs.llm-agents.packages.${system}.dsh;
      in
        pkgs.symlinkJoin {
          name = "deepseek-harness";
          paths = [dsh];
          buildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/dsh \
              --prefix NODE_PATH : "${dsh}/lib/node_modules/@deepseek-ai/dsh/node_modules"
          '';
        };

      # pydantic/monty sandboxed Python interpreter, e.g. `nix run .#monty -- -c "1 + 1"`;
      # also the worker binary behind the dsh `python_repl` tool (home/plugins/dsh-tool-monty)
      monty = pkgs.callPackage ./pkgs/monty-runtime.nix {};

      # The dsh plugin with its vendored npm deps, e.g. `nix build .#dsh-tool-monty`
      dsh-tool-monty = pkgs.callPackage ./pkgs/dsh-tool-monty.nix {
        monty-runtime = self.packages.${system}.monty;
      };

      # Archify architecture diagram tool & agent skill CLI
      archify = pkgs.callPackage ./pkgs/archify.nix {};

      # Agent Substrate (docs/ax_stack_todo.md): `kubectl-ate` + the control
      # plane binaries, and a script that pushes their OCI images to Forgejo,
      # e.g. `nix run .#agent-substrate-push-images`
      agent-substrate = (pkgs.callPackage ./pkgs/agent-substrate.nix {}).substrate;
      agent-substrate-push-images = (pkgs.callPackage ./pkgs/agent-substrate.nix {}).push;

      # google/ax on top of it: the `ax` CLI (also ax-server/-controller/
      # -task-runner binaries) and the image push, e.g. `nix run .#ax-push-images`
      ax = axBundle.ax;
      ax-push-images = axBundle.push;

      # "IPython is All You Need" shell, see pkgs/ipython-shell.nix
      ipython-shell = pkgs.callPackage ./pkgs/ipython-shell.nix {};

      # The same idea for nushell: `nubuddy "prompt"` or `ask` in the REPL, see pkgs/nubuddy.nix
      nubuddy = pkgs.callPackage ./pkgs/nubuddy.nix {};
    };

    nixosConfigurations = {
      meshify = mkHost "meshify" [
        inputs.agenix.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        hermes-agent.nixosModules.default
        {_module.args = inputs;}
      ];
      superserver = mkHost "superserver" [
        inputs.agenix.nixosModules.default
      ];
      poweredge = mkHost "poweredge" [];
      razerblade = mkHost "razerblade" [
        {_module.args = inputs;}
      ];
      desg0 = mkHost "desg0" [
        inputs.agenix.nixosModules.default
        {_module.args = inputs;}
      ];
      de-msa2 = mkHost "de-msa2" [
        inputs.agenix.nixosModules.default
        inputs.monty-persona.nixosModules.default
        {_module.args = inputs;}
      ];
      de-n5 = mkHost "de-n5" [
        inputs.agenix.nixosModules.default
        {_module.args = inputs;}
      ];
      tensorbook = mkHost "tensorbook" [
        {_module.args = inputs;}
      ];
    };
    formatter.${system} = treefmtEval.config.build.wrapper;
    apps = {
      "${system}" = rec {
        default = list_apps;
        list_apps =
          (inputs.flake-utils.lib.mkApp {
            drv = (import ./scripts/list_apps.nix {inherit self pkgs system;}).script;
          })
          // {meta.description = "List all applications in this flake";};
        wake_on_lan =
          (inputs.flake-utils.lib.mkApp {
            drv = import scripts/wake_on_lan.nix {inherit self pkgs;};
          })
          // {meta.description = "Send a wake-on-lan packet to a host";};
        sync_starred_github_to_forgejo =
          (inputs.flake-utils.lib.mkApp {
            drv = import scripts/sync_starred_github_to_forgejo.nix {inherit pkgs;};
          })
          // {meta.description = "Sync starred GitHub repositories to Forgejo";};
        llama_bench_matrix =
          (inputs.flake-utils.lib.mkApp {
            drv = import scripts/llama_bench_matrix.nix {inherit pkgs;};
          })
          // {meta.description = "Run llama-bench over a matrix of models and parameters";};
        hf =
          (inputs.flake-utils.lib.mkApp {
            drv = self.packages.${system}.hf;
            name = "hf";
          })
          // {meta.description = "Hugging Face CLI";};
        hf-stars =
          (inputs.flake-utils.lib.mkApp {
            drv = import scripts/hf_stars.nix {inherit pkgs;};
          })
          // {meta.description = "List starred Hugging Face repositories";};
        ax_apply =
          (inputs.flake-utils.lib.mkApp {
            drv = import scripts/ax_apply.nix {
              inherit pkgs;
              inherit (self.packages.${system}) ax;
            };
          })
          // {meta.description = "Apply ax Gateways/Workspaces/Tasks from manifests/ax";};
      };
    };
  };
}
