{
  flake.modules.homeManager.default =
    { ... }:
    {
      # Mirrors the smart case and dotfile handling of the nixvim picker and Zed.
      programs.ripgrep = {
        enable = true;
        arguments = [
          "--smart-case"
          "--hidden"
          "--glob=!.git/"
        ];
      };
    };
}
