{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.wezterm = {
        enable = false;
        extraConfig = /* lua */ ''
          return {
            color_scheme = "Gruvbox dark, hard (base16)",
            font = wezterm.font("JetBrainsMono Nerd Font"),
            font_size = 13.0,
            hide_tab_bar_if_only_one_tab = true,
          }
        '';
      };
      xdg.configFile = lib.mkIf config.programs.wezterm.enable {
        "wezterm/colors/Flexoki Dark.toml".source = "${pkgs.flexoki}/share/wezterm/Flexoki Dark.toml";
        "wezterm/colors/Flexoki Light.toml".source = "${pkgs.flexoki}/share/wezterm/Flexoki Light.toml";
      };
    };
}
