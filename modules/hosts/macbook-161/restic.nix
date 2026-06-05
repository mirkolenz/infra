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
        repository = "s3:https://s3.eu-central-2.wasabisys.com/restic-macbook-161";
        passwordFile = "/etc/nixos/secrets/restic-wasabi.passwd";
        # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
        environmentFile = "/etc/nixos/secrets/restic-wasabi.env";
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
