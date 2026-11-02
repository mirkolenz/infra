{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        config = {
          global = {
            disable_stdin = true;
            hide_env_diff = true;
            load_dotenv = false;
            strict_env = true;
            warn_timeout = "0s";
            # to silence the output
            # log_format = "-";
            # log_filter = "^$";
          };
        };
      };
    };
}
