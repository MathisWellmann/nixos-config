let
  user_de_msa2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9KGI7L08vgpSrbArGJk3JDW2jq/T6t3/NmJOxGmQhe";
  system_de_msa2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInemmTsfkJAbLR9IJ3KCnZxpkWzPemkgDvjnSoR9xu7";

  user_elitedesk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrgJsyt/t6syLHGj8BmTNDhstrqJnlODq4pNV82OR3N";
  system_elitedesk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGuoz8Wyj/GAnPDpkIBVtg5+fWOt/sfyZ4tHeT47q8g";

  user_desg0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAtbndl4uPNgCcQFyffE6yD0sUzp96bhaCQdMHUR6iqN";
  system_desg0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIECiXqvyc2hfQ4vOTGfamVQhzA+KVk2r0AjnVnpx3kTo";
in {
  "k3s_token.age" = {
    publicKeys = [
      user_de_msa2
      system_de_msa2
      user_elitedesk
      system_elitedesk
      user_desg0
      system_desg0
    ];
    armor = true;
  };
}
