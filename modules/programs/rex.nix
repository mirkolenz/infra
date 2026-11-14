# Rex terminal multiplexer, reached from other machines over ssh:// so that nothing listens
# on the network and sshd decides who gets in. On Linux, rex starts a personal server on
# demand, which exits once idle and so picks up updates by itself. On macOS the Rex app runs it.
{
  flake.modules.homeManager.default =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.rex = {
        enable = true;
        # Without the guard, the server gives its terminals xterm-256color instead of xterm-rex.
        sshGuard = config.programs.ssh.enable;
      };
      # logind removes /run/user at logout without lingering, which would orphan the server
      # and its sessions. Outside of it, the server outlives the login like tmux or herdr.
      home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        REX_RUNTIME_DIR = "${config.xdg.stateHome}/rex/run";
      };
    };
}
