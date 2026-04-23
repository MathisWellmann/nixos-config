{pkgs, ...}: let
  my-python-packages = ps:
    with ps; [
      numpy
      openai # Not using ClosedAi, but the package allows interacting with locally hosted ai services as well
      # pymc3 # markov chain monte carlo methods.
      matplotlib # Plotting
    ];
in {
  home.packages = with pkgs; [
    (python312.withPackages my-python-packages)
  ];
}
