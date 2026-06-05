{
  configurations.nixos.macbook-91.module = {
    users.users = {
      root.hashedPasswordFile = "/etc/nixos/secrets/root.passwd";
      mirko.hashedPasswordFile = "/etc/nixos/secrets/mirko.passwd";
      mila.hashedPasswordFile = "/etc/nixos/secrets/mila.passwd";
      levi.hashedPasswordFile = "/etc/nixos/secrets/levi.passwd";
    };
  };
}
