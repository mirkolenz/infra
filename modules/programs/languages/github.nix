{
  flake.modules.generic.languages =
    { pkgs, ... }:
    {
      custom = {
        # The workflows of GitHub Actions, a kind of YAML.
        languages.githubactions = {
          files = [
            ".github/workflows/*.yaml"
            ".github/workflows/*.yml"
          ];
          editors = {
            # Neovim and Fresh know them as YAML, where zizmor attaches to the workflows only.
            neovim.names = [ "yaml" ];
            fresh.names = [ ];
            zed = {
              names = [ "GitHub Actions" ];
              extensions = [ "github-actions" ];
            };
          };
          servers = [
            "yamlls"
            "zizmor"
          ];
          # actionlint stays disabled while its bundled metadata rejects newer features of
          # GitHub, such as `cache-mode`, `background` steps and the ubuntu-26.04 runners.
          fixers = [
            # "actionlint"
            "zizmor"
          ];
          formatter.tool = "oxfmt";
        };

        lsp.servers.zizmor = {
          package = pkgs.zizmor;
          args = [ "--lsp" ];
          linter = true;
          editors.zed = {
            name = "zizmor-lsp";
            extension = "zizmor";
          };
        };

        tools = {
          actionlint = {
            package = pkgs.actionlint;
            linter = true;
          };
          # Offline, since the checks build without network access.
          zizmor = {
            package = pkgs.zizmor;
            args = [
              "--offline"
              "--persona=pedantic"
            ];
            linter = true;
          };
        };
      };
    };
}
