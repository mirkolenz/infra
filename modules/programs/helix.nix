{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.helix = {
        enable = true;
        defaultEditor = false;
        # https://docs.helix-editor.com/languages.html
        languages = { };
        # https://docs.helix-editor.com/configuration.html
        settings = {
          theme = "gruvbox_dark_hard";
        };
        # https://docs.helix-editor.com/themes.html
        themes = {
          flexoki-dark = "${pkgs.flexoki}/share/helix/flexoki-dark.toml";
          flexoki-light = "${pkgs.flexoki}/share/helix/flexoki-light.toml";
        };
      };
    };
}
