# "Intelligent IPython shell" from
# https://nathancooper.io/blog/2026-08-10-ipython-is-all-you-need
#
# Exposes `ipython` with everything the post uses: ipythonng/kittytgp (images
# in the terminal), python-fastllm + rich (AI chat), safecmd/safepyrun/pyskills
# (safe code execution for the AI), fastcore 2.x.
#
# The 11 packages in `passthru` are not in nixpkgs — except fastcore, whose
# nixpkgs version (1.14.5) is too old for python-fastllm (needs >=2.1.18), so
# they are pulled from PyPI wheels. Everything else comes from nixpkgs.
{
  fetchurl,
  lib,
  python313,
  python313Packages,
}: let
  # Pure-Python (or platform) wheel from PyPI, no build step.
  # ponytail: buildPythonPackage (not buildPythonApplication) so the env's
  # requiredPythonModules filter keeps them in site-packages.
  pypi = {
    pname,
    version,
    url,
    sha256,
    deps ? [],
    postInstall ? "",
  }:
    python313Packages.buildPythonPackage {
      inherit pname version;
      format = "wheel";
      src = fetchurl {inherit url sha256;};
      dependencies = deps;
      inherit postInstall;
    };

  pypiPkgs = rec {
    # ponytail: pinned to today's PyPI releases; bump this block to update
    fastcore = pypi {
      pname = "fastcore";
      version = "2.2.19";
      url = "https://files.pythonhosted.org/packages/b2/57/8669593516849c19308841adff3d8cb4e9df506f002173ba7c41e7d5d19e/fastcore-2.2.19-py3-none-any.whl";
      sha256 = "739c548361ef83680f84cc7bef649c4990af28cbcf16ee86c7690514c195e1c2";
    };
    kittytgp = pypi {
      pname = "kittytgp";
      version = "0.0.2";
      url = "https://files.pythonhosted.org/packages/03/54/15d79ee63b06dc811ba4155e0a114cfc1573aecd670272ff215c8d80a68f/kittytgp-0.0.2-py3-none-any.whl";
      sha256 = "0121a57446079f405824c3604beaa88583dbecd031953cbb755db2fb6d0525cf";
    };
    aidialog = pypi {
      pname = "aidialog";
      version = "0.0.22";
      url = "https://files.pythonhosted.org/packages/a9/d5/f8c0942c19c693da7bc068d820bb7d53cbcb8a0eceae232d27e926e8a139/aidialog-0.0.22-py3-none-any.whl";
      sha256 = "c2d03e6293a6d3f588c6ef45af19e6472800f6a3df7f9a90610f8ccf68d6a76f";
      deps = [fastcore];
    };
    fasttransport = pypi {
      pname = "fasttransport";
      version = "0.0.2";
      url = "https://files.pythonhosted.org/packages/aa/af/4a5ea7ccd96cc5a4547e3a924eaba9a85cf7d78c31de25e32615f7cffb4b/fasttransport-0.0.2-py3-none-any.whl";
      sha256 = "e0173bf2d2785da31b940463713d9e90a5d15dc1c9764ff233e7214b321ae150";
      deps = [fastcore python313Packages.httpx2];
    };
    fastaudit = pypi {
      pname = "fastaudit";
      version = "0.2.9";
      url = "https://files.pythonhosted.org/packages/bf/2a/61b35f73627d91e12e7fed6013f0b763130f82080407090950d1c16757a9/fastaudit-0.2.9-py3-none-any.whl";
      sha256 = "29ba5f147b23d52454c53bb42d12d849f58e3b7cc5459b29d63a31e678ff4837";
      deps = [fastcore];
    };
    shfmt-py = pypi {
      pname = "shfmt-py";
      version = "4.1.0";
      url = "https://files.pythonhosted.org/packages/0f/b2/101c166f6f1895a7e4b2062d350bf156097087ffc95f772877e51c04358d/shfmt_py-4.1.0-py2.py3-none-manylinux2014_x86_64.whl";
      sha256 = "4f1573856d84725f148175ef56532365dc4a7e5332e27c31b6c82be544ad2bda";
    };
    ipythonng = pypi {
      pname = "ipythonng";
      version = "0.0.4";
      url = "https://files.pythonhosted.org/packages/4d/d8/9a1c78fd69713298c0819ea8f2814e63e3b3af2a87643021e80abf10d213/ipythonng-0.0.4-py3-none-any.whl";
      sha256 = "06c6ee569529f8c63100d98bbfd0f8f503641840d4142ef6c353bc4dd8fd4e4c";
      deps = with python313Packages; [ipython rich kittytgp];
    };
    pyskills = pypi {
      pname = "pyskills";
      version = "0.0.28";
      url = "https://files.pythonhosted.org/packages/09/25/642d919858d135f17015329f9f33a05ec33363207d4d8b6b1436085a97d5/pyskills-0.0.28-py3-none-any.whl";
      sha256 = "b31f7383ea51cc80e486e55d79d158f950a1743d1236325cb481050ffd99716b";
      deps = [fastaudit fastcore];
    };
    safecmd = pypi {
      pname = "safecmd";
      version = "0.1.15";
      url = "https://files.pythonhosted.org/packages/07/70/90da35ba00cba2f7cd4f8cc6186a49b4e7f79d124fb4ed86d9e5c0de916a/safecmd-0.1.15-py3-none-any.whl";
      sha256 = "fe19e01af46561e82fb9ff439b549b0f144c86d8fcf0affa132358533b3dcc8b";
      deps = [fastcore shfmt-py];
    };
    python-fastllm = pypi {
      pname = "python-fastllm";
      version = "0.0.45";
      url = "https://files.pythonhosted.org/packages/f1/68/1bf716c11da112bbe062b88e18cc892cded34d64825356360b2b51508a46/python_fastllm-0.0.45-py3-none-any.whl";
      sha256 = "7b4b0617b1bde9fcabed479da2d26065e1a8ead9359ba31a5b6664629493e6f4";
      deps = with python313Packages; [pillow fastcore aidialog fasttransport];
      # fastllm downloads a model-price cache into its own module dir on first
      # import; the Nix store is read-only, so pre-create it (empty = no cost metadata).
      postInstall = ''
        echo '{}' > "$out/${python313.sitePackages}/fastllm/model_prices.json"
      '';
    };
    safepyrun = pypi {
      pname = "safepyrun";
      version = "0.2.7";
      url = "https://files.pythonhosted.org/packages/4a/f3/01191fdfbf441874f8627ec4e7b889e64fa4f3b4661bb0e63421583e5622/safepyrun-0.2.7-py3-none-any.whl";
      sha256 = "b2e6179cc31cadc1e0d1bd56938bb4b26d522d81556f309327cf50a3eeb7dc13";
      deps = with python313Packages; [httpx matplotlib fastaudit pyskills fastcore];
    };

    ipython-shell =
      python313.withPackages (ps:
        with ps; [
          # from nixpkgs
          ipython
          matplotlib
          rich
          pillow
          httpx
          httpx2
          # from PyPI (see above)
          fastcore
          kittytgp
          aidialog
          fasttransport
          fastaudit
          shfmt-py
          ipythonng
          pyskills
          safecmd
          python-fastllm
          safepyrun
        ])
      // {
        meta = {
          description = "IPython as your shell, per nathancooper.io's 'IPython is All You Need'";
          homepage = "https://nathancooper.io/blog/2026-08-10-ipython-is-all-you-need";
          license = lib.licenses.bsd3;
          platforms = python313.meta.platforms;
          mainProgram = "ipython";
        };
        # Expose the individual PyPI builds at the top level so consumers can
        # merge them into their own withPackages env — two withPackages envs
        # in one buildEnv collide on the shared interpreter bins.
        inherit
          fastcore
          kittytgp
          aidialog
          fasttransport
          fastaudit
          shfmt-py
          ipythonng
          pyskills
          safecmd
          python-fastllm
          safepyrun
          ;
      };
  };
in
  pypiPkgs.ipython-shell
