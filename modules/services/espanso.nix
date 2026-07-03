{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      services.espanso = {
        enable = false;
        configs.default = { };
        matches.base = {
          matches = [
            {
              trigger = ":al";
              replace = "aarch64-linux";
            }
            {
              trigger = ":xl";
              replace = "x86_64-linux";
            }
            {
              trigger = ":ad";
              replace = "aarch64-darwin";
            }
            {
              trigger = ":xd";
              replace = "x86_64-darwin";
            }
          ];
        };
      };
    };
}
