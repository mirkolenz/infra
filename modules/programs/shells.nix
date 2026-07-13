{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      home.shell.enableShellIntegration = true;
      programs.fish = {
        enable = true;
        generateCompletions = true;
        functions.fish_greeting.body = ''
          if set -q SSH_CONNECTION
            ${lib.getExe config.programs.macchina.package}
          end
        '';
      };
      xdg.configFile = {
        "fish/themes/flexoki-dark.theme".source = "${pkgs.flexoki}/share/fish/flexoki-dark.theme";
        "fish/themes/flexoki-light.theme".source = "${pkgs.flexoki}/share/fish/flexoki-light.theme";
      };
      # A trailing space makes bash/zsh alias-expand the word after `sudo`, so
      # aliases like ll or la keep working under sudo. mkDefault lets the
      # standalone module override the command (e.g. the generic Linux PATH shim).
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        fastSyntaxHighlighting.enable = true;
        shellAliases.sudo = lib.mkDefault "sudo ";
      };
      programs.bash = {
        enable = true;
        enableCompletion = true;
        shellAliases.sudo = lib.mkDefault "sudo ";
      };
      # this is slow
      programs.man.generateCaches = false;
    };
}
