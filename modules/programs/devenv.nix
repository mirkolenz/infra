{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    lib.mkIf config.custom.features.extras.enable {
      programs.devenv.enable = true;
      custom.bump.devenv = {
        lockfile = "devenv.lock";
        commands = [
          [
            (lib.getExe config.programs.devenv.package)
            "update"
          ]
        ];
      };
    };
}
