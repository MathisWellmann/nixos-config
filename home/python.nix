{ pkgs, inputs, ... }: let
  my-python-packages = ps:
    with ps; [
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
    ];
in {
  home.packages = with pkgs; [
    (python313.withPackages my-python-packages)
    uv # Python package manager

    # "IPython is All You Need" blog post: ipython CLI + ipythonng, fastllm,
    # safecmd/safepyrun, fastcore 2.x (see pkgs/ipython-shell.nix)
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ipython-shell
  ];
}
