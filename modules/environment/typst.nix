{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        typst-bin
        typstyle
        tinymist
      ];
      # No `--open`: typst spawns the viewer detached, which a terminal UI cannot take over.
      # Preview with `tdf out.pdf` in a second pane, it reloads whenever the PDF changes.
      home.shellAliases = {
        typc = "typst compile --root .";
        typw = "typst watch --root .";
      };
    };
}
