{
  flake.modules.homeManager.default =
    {
      pkgs,
      lib,
      config,
      ...
    }@args:
    {
      programs.fish = {
        enable = true;
        # fish generates the man page completions at runtime instead of one derivation per package
        generateCompletions = false;
        functions.fish_greeting.body = ''
          if set -q SSH_CONNECTION
            ${lib.getExe config.programs.fastfetch.package}
          end
        '';
      };
      # Regenerates the man page completions in the background whenever the user or system packages change.
      # A login shell is needed, as `man --path` derives the man pages from PATH.
      xdg.dataFile."fish/home-manager/packages" = {
        text = lib.concatLines (
          [ "${config.home.path}" ] ++ lib.optional (args ? osConfig) "${args.osConfig.system.path}"
        );
        onChange = ''
          run ${lib.getExe config.programs.fish.package} --login \
            --command 'fish_update_completions_detach=true fish_update_completions'
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
        fastSyntaxHighlighting.enable = true;
        shellAliases.sudo = lib.mkDefault "sudo ";
      };
      programs.bash = {
        enable = true;
        shellAliases.sudo = lib.mkDefault "sudo ";
      };
    };
}
