# Helpers without a better home, and the `lib'` argument of the flake-parts
# modules. modules/core passes it on to the option modules under options/,
# which have no flake-parts scope. Each file of this directory adds to
# `flake.lib`, and helpers refer to each other through `lib'`, the merged set.
{ lib, config, ... }:
{
  _module.args.lib' = config.flake.lib;

  flake.lib = {
    # return [ path ] if it exists, otherwise [ ]
    optionalPath = path: lib.optional (lib.pathExists path) path;
    # resolved nix daemon socket path as a sandbox sees it after symlink resolution.
    # on darwin determinate-nixd symlinks the default /nix/var/nix/daemon-socket/socket
    # to /var/run/nix-daemon.socket, which the /var firmlink resolves to /private/var/run.
    # on linux the default location is a real socket, so no rewriting is needed.
    nixDaemonSocket =
      stdenv:
      if stdenv.hostPlatform.isDarwin then
        "/private/var/run/nix-daemon.socket"
      else
        "/nix/var/nix/daemon-socket/socket";
  };
}
