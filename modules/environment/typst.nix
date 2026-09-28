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
      # The project imports its copy by path, e.g. `#import "/vendor/typst/lib.typ": *`,
      # which works both locally and in the typst.app web app.
      custom.vendor.typst = {
        source = checkout;
        target = "vendor/typst";
      };
      # https://polylux.dev/book/external/pdfpc.html
      # https://touying-typ.github.io/docs/external/pdfpc
      custom.commands.typst2pdfpc.text = /* bash */ ''
        # @describe Export the pdfpc speaker notes of a Typst presentation next to it
        # @arg file!        Typst file, with or without its extension
        # @arg typst-args~  Further arguments of typst eval

        file="''${argc_file%.typ}"

        exec ${lib.getExe pkgs.typst-bin} eval "''${argc_typst_args[@]}" --root . \
          'query(<pdfpc-file>).first().value' \
          --in "./$file.typ" \
          > "./$file.pdfpc"
      '';
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
