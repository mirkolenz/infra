{
  pkgs,
  lib,
  config,
  ...
}:
let
  pythonWithPackages = pkgs.python3.withPackages (ps: with ps; [ typer ]);
in
lib.mkIf config.custom.features.withOptionals {
  home.sessionVariables = {
    RUST_SRC_PATH = pkgs.rustPlatform.rustLibSrc;
  };
  programs = {
    go.enable = true;
    gradle.enable = true;
    java.enable = true;
    mods.enable = true;
  };
  home.packages = with pkgs; [
    exiftool
    fontforge
    unpaper
    buf
    gomplate
    grpcui
    mqttui
    plantuml
    pre-commit
    mu-repo
    cc2538-bsl
    imagemagick
    pngquant
    poppler-utils
    pstoedit
    ffmpeg
    ffmpeg-normalize
    qpdf
    comrak
    mdbook
    treefmt-nix
    uv-migrator
    llm
    ghostscript
    janice
    harper
    protobuf-language-server
    touying
    mcp-proxy
    pdfpc
    pympress
    keep-sorted
    jsonfmt
    caddy
    mailpit
    copilot-cli-bin
    html2markdown
    zapp
    # nix
    nixd
    nixf-diagnose
    nixfmt-rs
    nix-update
    devenv
    nurl
    hydra-check
    nixos-render-docs
    nix-converter
    nix-sweep
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
    copilot-language-server
    jdt-language-server
    tombi
    # my own packages
    makejinja
  ];
}
