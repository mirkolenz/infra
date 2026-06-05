{
  configurations.nixos.macpro.module =
    { config, ... }:
    {
      users.users = {
        root.hashedPasswordFile = "/etc/nixos/secrets/root.passwd";
        ${config.custom.user.login}.hashedPasswordFile =
          "/etc/nixos/secrets/${config.custom.user.login}.passwd";
      };
    };
}
