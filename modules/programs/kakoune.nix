{
  flake.modules.homeManager.default =
    { pkgs, ... }:
    {
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
