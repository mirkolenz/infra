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
    # todo: once out of beta, use hardcoded package path instead of plain `op` command
    stdlib = ''
      use_op() {
        set -a
        source <(op environment read "$1")
        set +a
      }
    '';
  };
}
