{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.kakoune = {
        enable = true;
        config = {
          indentWidth = 2;
          ui = {
            enableMouse = true;
          };
        };
        plugins = with pkgs.kakounePlugins; [
          fzf-kak
          kakoune-lsp
        ];
      };
    };
}
