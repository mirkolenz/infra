{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
      programs.helix = {
        enable = true;
        defaultEditor = false;
        # https://docs.helix-editor.com/languages.html
        languages = { };
        # https://docs.helix-editor.com/configuration.html
        settings = {
          theme = "gruvbox_dark_hard";
        };
      };
      # https://docs.helix-editor.com/themes.html
      xdg.configFile = {
        "helix/themes/flexoki-dark.toml".source = "${pkgs.flexoki}/share/helix/flexoki-dark.toml";
        "helix/themes/flexoki-light.toml".source = "${pkgs.flexoki}/share/helix/flexoki-light.toml";
      };
    };
}
