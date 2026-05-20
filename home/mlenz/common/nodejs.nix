{
  lib,
  config,
  pkgs,
  ...
}:
lib.mkIf config.custom.features.withOptionals {
  programs.bun.enable = true;
  programs.npm = {
    enable = true;
    # https://blog.npmjs.org/post/141702881055/package-install-scripts-vulnerability
    settings = {
      prefix = "\${HOME}/.npm";
      ignore-scripts = true;
      min-release-age = 3; # days
      allow-git = "none";
    };
  };
  home.packages = with pkgs; [
    nodejs
    prettier
    svgo
    npm-check-updates
    biome
    oxfmt
    oxlint
    tsgolint
    typescript-go
    astro-language-server
  ];
}
