{
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  # "IPython is All You Need" blog-post packages (see pkgs/ipython-shell.nix).
  # Merged into the main env below: two `withPackages` envs in home.packages
  # collide in buildEnv on the shared interpreter bins (normalizer, pydoc, …).
  buddy = inputs.self.packages.${system}.ipython-shell;
in {
  home.packages = with pkgs; [
    (python313.withPackages (ps:
      with ps;
      [
        numpy
        openai # Not using ClosedAi, but the package allows interacting with locally hosted ai services as well
        # pymc # markov chain monte carlo methods.
        scipy
        scikit-learn
        matplotlib # Plotting
        # rerun-sdk
        requests
        beautifulsoup4
        pip

        # "IPython is All You Need" blog post: ipython CLI + ipythonng, fastllm,
        # safecmd/safepyrun, fastcore 2.x
        ipython
        rich
        pillow
        httpx
        httpx2
        buddy.fastcore
        buddy.kittytgp
        buddy.aidialog
        buddy.fasttransport
        buddy.fastaudit
        buddy.shfmt-py
        buddy.ipythonng
        buddy.pyskills
        buddy.safecmd
        buddy.python-fastllm
        buddy.safepyrun
      ]))
    uv # Python package manager
  ];

  # "bash buddy": blog-post shell setup, auto-loaded on every `ipython` start.
  # Inference provider points at the local sglang server (desg0:8000).
  home.file = {
    ".ipython/profile_default/startup/90-bash-buddy.py".source = ./bash-buddy.py;
  };
}
