{
  flake.modules.homeManager.default =
    { pkgs, lib, ... }:
    let
      yamlFormat = pkgs.formats.yaml { };
    in
    lib.mkIf pkgs.stdenv.isDarwin {
      # https://github.com/ianyh/Amethyst/blob/development/.amethyst.sample.yml
      # https://github.com/ianyh/Amethyst/blob/development/Amethyst/default.amethyst
      home.file.".amethyst.yml".source = yamlFormat.generate "amethyst-config.yml" {
        layout = [
          "tall"
          "fullscreen"
          "wide"
          "column"
        ];
      };
    };
}
