# 1Password-backed secrets. Consumers reference the resolved paths through
# `config.services.onepassword-secrets.secretPaths.<name>`, so cleartext values
# never enter the nix store or the git repo.
{
  configurations.nixos.macbook-161.module = {
    systemd.services.opnix-secrets = {
      enableStrictShellChecks = false;
    };

    services.onepassword-secrets = {
      enable = true;
      secrets = {

        resticWasabiRepository = {
          reference = "op://NixOS/MacBook 161 Restic/repository";
          services = [ "restic-backups-wasabi" ];
        };

        resticWasabiPassword = {
          reference = "op://NixOS/MacBook 161 Restic/credential";
          services = [ "restic-backups-wasabi" ];
        };

        resticWasabiEnv = {
          reference = "op://NixOS/MacBook 161 Wasabi/env";
          services = [ "restic-backups-wasabi" ];
        };

      };
    };
  };
}
