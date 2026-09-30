{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
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
        prettier
        svgo
        npm-check-updates
        biome
        oxfmt
        oxlint
        tsgolint
        typescript
        astro-language-server
      ];
      custom.bump.npm = {
        files = [
          "package.json"
          "package-lock.json"
        ];
        text = ''
          ${lib.getExe pkgs.npm-check-updates} --interactive --format group --install never
          ${lib.getExe' config.programs.npm.package "npm"} update
        '';
      };
      custom.bump.bun = {
        files = [
          "package.json"
          "bun.lock"
        ];
        text = "${lib.getExe config.programs.bun.package} update";
      };
    };
}
