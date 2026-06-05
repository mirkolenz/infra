{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.tex-fmt = {
        enable = true;
        settings = {
          wrap = false;
          tabsize = 2;
          tabchar = "space";
          lists = [
            "enumerate*"
            "itemize*"
            "description*"
          ];
        };
      };
    };
}
