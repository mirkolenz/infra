# Bootstrap payload for macOS machines without Nix: a `~`-rooted tree of the
# configs that `mirkos-macbook-rsync` copies to a remote host. Living in
# `system.build` (a lazy attrset) keeps it out of every evaluation that only
# touches the package set.
{
  configurations.darwin.mirkos-macbook.module =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      hmCfg = config.home-manager.users.${config.system.primaryUser};

      # Zed rewrites its JSON config at runtime, so it is installed by an
      # activation script rather than home.file; copy the sources straight from
      # this flake.
      zedDir = ../../programs/zed;
      zedFiles = lib.concatMapAttrs (
        name: _:
        lib.optionalAttrs (lib.hasSuffix ".json" name) {
          ".config/zed/${name}" = zedDir + "/${name}";
        }
      ) (builtins.readDir zedDir);
    in
    {
      system.build.remoteConfig = pkgs.linkFarm "mirkos-macbook-remote-config" (
        {
          ".config/ghostty/config" = hmCfg.xdg.configFile."ghostty/config".source;
          ".config/homebrew/Brewfile" = pkgs.writeText "Brewfile" config.homebrew.brewfile;
          ".ssh/config" = hmCfg.home.file.".ssh/config".source;
        }
        // zedFiles
      );
    };
}
