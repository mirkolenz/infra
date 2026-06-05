{
  flake.modules.homeManager.default =
    { ... }:
    {
      # https://github.com/ajeetdsouza/zoxide#configuration
      programs.zoxide = {
        enable = true;
        options = [
          "--cmd"
          "z"
          "--hook"
          "prompt"
        ];
      };
      home.sessionVariables = {
        _ZO_ECHO = true;
        _ZO_MAXAGE = 10000;
        _ZO_RESOLVE_SYMLINKS = true;
      };
      home.sessionSearchVariables = {
        _ZO_EXCLUDE_DIRS = [
          "$HOME"
          "$HOME/.*"
          "$HOME/Downloads/**"
          "$HOME/Library/**"
          "/"
          "/nix/**"
          "/tmp/**"
        ];
      };
    };
}
