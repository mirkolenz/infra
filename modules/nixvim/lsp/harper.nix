{
  flake.modules.nixvim.default = {
    lsp.servers.harper_ls = {
      enable = true;
      # https://writewithharper.com/docs/integrations/language-server
      config.settings.harper-ls = {
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
    };
  };
}
