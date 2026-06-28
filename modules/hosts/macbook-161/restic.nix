{
  configurations.nixos.macbook-161.module =
    { config, ... }:
    {
      services.restic.backups.wasabi = {
        initialize = true;
        paths = [
          "/home/${config.custom.user.login}"
        ];
        exclude = [
          ".cache"
          ".devenv"
          ".direnv"
          ".local/share/Trash"
          ".venv"
          "__pycache__"
          "node_modules"
        ];
        repositoryFile = config.services.onepassword-secrets.secretPaths.resticWasabiRepository;
        passwordFile = config.services.onepassword-secrets.secretPaths.resticWasabiPassword;
        environmentFile = config.services.onepassword-secrets.secretPaths.resticWasabiEnv;
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
      };
    };
}
