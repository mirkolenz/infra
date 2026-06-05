{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      home.packages = with pkgs; [
        typst-bin
        typstyle
        tinymist
      ];
      home.shellAliases = {
        typc = "typst compile --root . --open skim";
        typw = "typst watch --root . --open skim";
      };
    };
}
