{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.bat = {
        enable = true;
        config = {
          style = "plain";
          theme = "Monokai Extended";
        };
      };
    };
}
