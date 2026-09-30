{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    {
      programs.devenv.enable = true;
      custom.bump.devenv = {
        files = [ "devenv.lock" ];
        text = "${lib.getExe config.programs.devenv.package} update";
      };
    };
}
