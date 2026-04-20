{hostname ? "desg0"}: _: {
  # Use remote builder machine
  # Make sure the `root` user can `ssh` into the host:
  # sudo mkdir -p /root/.ssh
  # sudo cp ~/.ssh/* /root/.ssh/
  # sudo chmod 600 /root/.ssh/*
  nix = {
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "desg0";
        sshUser = "m";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 4;
        speedFactor = 2;
        systems = ["x86_64-linux"];
        # supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
        # mandatoryFeatures = [];
      }
    ];
    extraOptions = ''
      builders-use-substitutes = true
    '';
  };
}
