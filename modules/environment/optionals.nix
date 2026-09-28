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
      home.sessionVariables = {
        RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
      };
      home.shellAliases = {
        tdf = "${lib.getExe pkgs.tdf} --fullscreen";
      };
      programs = {
        go.enable = true;
        gradle.enable = true;
        java.enable = true;
        mods.enable = true;
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
        # go
        gopls
        delve
        go-outline
        goreleaser
        # python
        pythonWithPackages
        pylyzer
        basedpyright
        zuban
        pyrefly-bin
        # rust
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
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
