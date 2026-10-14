{
  flake.modules.homeManager.default =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    lib.mkIf config.custom.features.extras.enable {
      programs.bun = {
        enable = true;
        # https://bun.com/docs/runtime/bunfig
        settings.install.minimumReleaseAge = config.custom.minReleaseAge * 24 * 60 * 60; # seconds
      };
      programs.npm = {
        enable = true;
        # https://blog.npmjs.org/post/141702881055/package-install-scripts-vulnerability
        # https://docs.npmjs.com/cli/v11/using-npm/config
        settings = {
          prefix = "\${HOME}/.npm";
          ignore-scripts = true;
          min-release-age = config.custom.minReleaseAge; # days
          allow-directory = "none";
          allow-file = "none";
          allow-git = "none";
          allow-remote = "none";
        };
      };
      home.packages = with pkgs; [
        svgo
        oxfmt
        oxlint
        tsgolint
        typescript
        astro-language-server
        shadcn
        mcp-inspector
      ];
      custom.bump.npm = {
        lockfile = "package-lock.json";
        pathspecs = [ ":(glob)**/package.json" ];
        text = ''
          ${lib.getExe pkgs.bump-ranges} node
          ${lib.getExe' config.programs.npm.package "npm"} update
        '';
      };
      custom.bump.bun = {
        lockfile = "bun.lock";
        pathspecs = [ ":(glob)**/package.json" ];
        text = ''
          ${lib.getExe pkgs.bump-ranges} node
          ${lib.getExe config.programs.bun.package} update --recursive
        '';
      };
    };
}
