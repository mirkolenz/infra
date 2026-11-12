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
          # ghostty widens the icon into the following space, so add a second one
          time.format = "[[   $time ](fg:color_fg0 bg:color_bg1)]($style)";
        };
      };
      # https://starship.rs/advanced-config/#transientprompt-and-transientrightprompt-in-fish
      programs.fish.functions.starship_transient_prompt_func = "printf '\\n\\n$ '";
    };
}
