{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.eza = {
        enable = true;
        extraOptions = [
          "--long"
          "--group-directories-first"
          "--color=auto"
          "--time-style=long-iso"
        ];
        git = true;
        icons = "auto";
      };
    };
}
