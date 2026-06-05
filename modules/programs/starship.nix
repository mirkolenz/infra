{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.starship = {
        enable = true;
        enableTransience = true;
        presets = [ "gruvbox-rainbow" ];
        settings = {
          add_newline = true;
          character = {
            success_symbol = "[](bold green)";
            error_symbol = "[](bold red)";
          };
          container.format = "[$symbol]($style) ";
          direnv = {
            format = "[$symbol$loaded]($style) ";
            symbol = " ";
            loaded_msg = "loaded";
            unloaded_msg = "unloaded";
            disabled = false;
          };
          nix_shell = {
            format = "[$symbol$state]($style) ";
            impure_msg = "nix-shell";
            pure_msg = "nix-shell";
            unknown_msg = "nix-shell";
          };
        };
      };
      # https://starship.rs/advanced-config/#transientprompt-and-transientrightprompt-in-fish
      programs.fish.interactiveShellInit = ''
        function starship_transient_prompt_func
          printf '\n\n$ '
        end
      '';
    };
}
