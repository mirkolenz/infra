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
      programs.zsh = {
        enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
      };
      programs.bash = {
        enable = true;
        enableCompletion = true;
      };
      # this is slow
      programs.man.generateCaches = false;
    };
}
