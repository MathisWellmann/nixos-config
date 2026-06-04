let
  user_de_msa2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInemmTsfkJAbLR9IJ3KCnZxpkWzPemkgDvjnSoR9xu7";
in {
  "k3s_token.age" = {
    publicKeys = [user_de_msa2];
    armor = true;
  };
}
