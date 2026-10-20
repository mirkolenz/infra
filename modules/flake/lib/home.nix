# Home-manager activation helpers for files that must stay writable or live
# in a checkout.
{
  self,
  lib,
  lib',
  ...
}:
{
  flake.lib = {
    # Symlink a file to its live location in the checked-out config repo
    # (`config.custom.configPath`) rather than the read-only store, so edits take
    # effect without a rebuild. `value` is a path within this repo; its prefix
    # relative to the repo root is reused under the checkout.
    # https://github.com/ncfavier/config/blob/bfc59fe3febc7a389105d05141215ca725bf7a9f/modules/nix.nix#L64-L68
    mkMutableSymlink =
      { config, value }:
      config.lib.file.mkOutOfStoreSymlink (
        config.custom.configPath + lib.removePrefix (toString self) (toString value)
      );

    # Home-manager activation entry that links `target` to the live checkout at
    # `checkout`, typically below `config.custom.projectsPath`, so edits take effect
    # without a rebuild. Hosts without the checkout are skipped, keeping it optional.
    mkCheckoutLink =
      {
        config,
        target,
        checkout,
      }:
      config.lib.dag.entryAfter [ "linkGeneration" ] ''
        if [[ -e ${lib.escapeShellArg checkout} ]]; then
          run mkdir -p $VERBOSE_ARG ${lib.escapeShellArg (dirOf target)}
          run ln -sfn $VERBOSE_ARG ${lib.escapeShellArg checkout} ${lib.escapeShellArg target}
        fi
      '';

    # Home-manager activation entry that installs writable copies of files after
    # linkGeneration. Use for programs that rewrite their own config and choke on
    # read-only store symlinks: the writable copy lets them work, while our
    # declared content is restored on every rebuild. `coreutils` (hence `install`)
    # is always on the activation PATH. `files` is a list of { source; target; mode ? "600"; }.
    mkMutableFiles =
      { config, files }:
      config.lib.dag.entryAfter [ "linkGeneration" ] (
        lib.concatMapStringsSep "\n" (
          {
            source,
            target,
            mode ? "600",
          }:
          "run install -Dm${mode} $VERBOSE_ARG ${source} ${target}"
        ) files
      );

    # Single-file variant of `mkMutableFiles`; takes one source/target directly.
    mkMutableFile =
      {
        config,
        source,
        target,
        mode ? "600",
      }:
      lib'.mkMutableFiles {
        inherit config;
        files = [ { inherit source target mode; } ];
      };
  };
}
