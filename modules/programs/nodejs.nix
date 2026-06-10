{
  flake.modules.homeManager.default =
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
        # https://docs.npmjs.com/cli/v11/using-npm/config
        settings = {
          prefix = "\${HOME}/.npm";
          ignore-scripts = true;
          min-release-age = 3; # days
          allow-directory = "none";
          allow-file = "none";
          allow-git = "none";
          allow-remote = "none";
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
        typescript
        typescript-go
        astro-language-server
      ];
    };
}
