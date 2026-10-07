{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      pythonWithPackages = pkgs.python3.withPackages (ps: with ps; [ typer ]);
    in
    lib.mkIf config.custom.features.extras.enable {
      home.shellAliases = {
        tdf = "${lib.getExe pkgs.tdf} --fullscreen";
      };
      programs = {
        gradle.enable = true;
        java.enable = true;
        mods.enable = true;
      };
      custom.bump = {
        buf = {
          files = [ "buf.lock" ];
          text = "${lib.getExe pkgs.buf} dep update";
        };
        # swift ships with xcode instead of nixpkgs
        swift = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
          files = [ "Package.resolved" ];
          text = "/usr/bin/swift package update";
        };
      };
      home.packages = with pkgs; [
        buf
        gomplate
        grpcui
        mqttui
        plantuml
        # pre-commit
        mu-repo
        cc2538-bsl
        comrak
        mdbook
        treefmt-nix
        llm
        # janice
        protobuf-language-server
        touying
        mcp-proxy
        pdfpc
        pympress
        keep-sorted
        jsonfmt
        caddy
        mailpit
        zapp
        restic-browser
        todoist-cli
        ripwire
        harlequin
        flow-control
        google-lighthouse
        caligula
        # markdown
        html2markdown
        md-tui
        glow
        # pdf
        # tdf # used via alias
        # fancy-cat # currently broken
        pdf-cli
        # office
        officecli-bin
        # python
        pythonWithPackages
        pylyzer
        basedpyright
        zuban
        pyrefly-bin
        # language servers
        bash-language-server
        docker-language-server
        jdt-language-server
        marksman
        texlab
        tombi
        vscode-langservers-extracted
        yaml-language-server
        # my own packages
        makejinja
      ];
    };
}
