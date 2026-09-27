{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      lib',
      pkgs,
      ...
    }:
    let
      checkout = "${config.custom.projectsPath}/mirkolenz/typst-lib";
      # Must match the typst.toml of the checkout, which pure evaluation cannot read.
      packageDir = "local/mirkolenz/0.1.0";
      # Typst resolves `@local` packages from its data directory, which ignores XDG on darwin.
      dataDir =
        if pkgs.stdenv.hostPlatform.isDarwin then
          "${config.home.homeDirectory}/Library/Application Support"
        else
          config.xdg.dataHome;
    in
    lib.mkIf config.custom.features.extras.enable {
      home.packages = with pkgs; [
        typst-bin
        typstyle
        tinymist
      ];
      # Vendors the library into the current project,
      # which selects it via `export TYPST_PACKAGE_PATH=$PWD/typst` in its .envrc.
      custom.commands.typstup = lib'.mkVendorScript {
        source = checkout;
        target = "typst/${packageDir}";
      };
      home.activation.linkTypstLibrary = lib'.mkCheckoutLink {
        inherit config checkout;
        target = "${dataDir}/typst/packages/${packageDir}";
      };
      # No `--open`: typst spawns the viewer detached, which a terminal UI cannot take over.
      # Preview with `tdf out.pdf` in a second pane, it reloads whenever the PDF changes.
      home.shellAliases = {
        typc = "typst compile --root .";
        typw = "typst watch --root .";
      };
    };
}
