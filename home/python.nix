{pkgs, ...}: let
  my-python-packages = ps:
    with ps; [
      numpy
      openai # Not using ClosedAi, but the package allows interacting with locally hosted ai services as well
      pymc # markov chain monte carlo methods.
      scipy
      scikit-learn
      matplotlib # Plotting
      rerun-sdk
      requests
      beautifulsoup4
      pip
    ];
in {
  home.packages = with pkgs; [
    (python313.withPackages my-python-packages)
  ];
}
