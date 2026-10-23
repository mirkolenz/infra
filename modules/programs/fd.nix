{
  flake.modules.homeManager.default =
    { ... }:
    {
      # Mirrors the dotfile handling of ripgrep.
      programs.fd = {
        enable = true;
        hidden = true;
        ignores = [ ".git/" ];
      };
    };
}
