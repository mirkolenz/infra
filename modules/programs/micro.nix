{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.micro = {
        enable = true;
        settings = {
          autosu = true;
          colorscheme = "monokai";
          diffgutter = true;
        };
      };
    };
}
