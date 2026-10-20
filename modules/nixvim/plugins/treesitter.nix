{
  flake.modules.nixvim = {
    default =
      { config, lib, ... }:
      {
        plugins.treesitter = {
          enable = true;
          folding.enable = true;
          highlight.enable = true;
          indent.enable = true;
          # Neovim bundles the c, lua, markdown, query, vim, and vimdoc parsers.
          grammarPackages = lib.mkDefault (
            with config.plugins.treesitter.package.builtGrammars;
            [
              bash
              comment
              diff
              fish
              git_config
              git_rebase
              gitattributes
              gitcommit
              gitignore
              json
              nix
              python
              regex
              toml
              yaml
            ]
          );
        };
      };
    extras =
      { config, ... }:
      {
        plugins.treesitter.grammarPackages = config.plugins.treesitter.package.passthru.allGrammars;
      };
  };
}
