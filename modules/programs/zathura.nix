{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      programs.zathura = {
        enable = pkgs.stdenv.hostPlatform.isLinux;
        options = {
          synctex = true;
          synctex-editor-command = "texlab inverse-search -i %{input} -l %{line}";
        };
      };
      xdg.configFile = {
        "zathura/flexoki-dark".source = "${pkgs.flexoki}/share/zathura/flexoki-dark";
        "zathura/flexoki-light".source = "${pkgs.flexoki}/share/zathura/flexoki-light";
      };
    };
}
