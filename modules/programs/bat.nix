{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    {
      programs.bat = {
        enable = true;
        config = {
          style = "plain";
          theme = "Monokai Extended";
        };
      };
      home.shellAliases.cat = lib.getExe config.programs.bat.package;
    };
}
