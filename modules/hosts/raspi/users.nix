{
  configurations.nixos.raspi.module =
    { config, ... }:
    {
      users.users = {
        ${config.custom.user.login}.hashedPasswordFile =
          "/etc/nixos/secrets/${config.custom.user.login}.passwd";
      };
    };
}
