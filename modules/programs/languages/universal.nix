# The servers and tools of every language.
{
  flake.modules.generic.languages =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      custom = {
        universal = lib.mkIf config.custom.features.extras.enable {
          # Prose linting.
          # https://writewithharper.com/docs/integrations/language-server
          servers = [ "harper_ls" ];
          # Sorts the blocks that keep-sorted marks with its comments.
          fixers = [ "keep-sorted" ];
        };

        lsp.servers.harper_ls = {
          package = pkgs.harper;
          args = [ "--stdio" ];
          linter = true;
          settings.harper-ls = {
            diagnosticSeverity = "hint";
            dialect = "American";
            isolateEnglish = true;
            maxFileLength = 1000000;
            # https://writewithharper.com/docs/rules
            linters = {
              LongSentences = false;
              MoreAdjective = false;
              NoFrenchSpaces = false;
              SentenceCapitalization = false;
              Spaces = false;
            };
          };
          editors.zed = {
            name = "harper-ls";
            extension = "harper";
          };
        };

        tools.keep-sorted = {
          package = pkgs.keep-sorted;
          stdinArgs = [ "-" ];
        };
      };
    };
}
