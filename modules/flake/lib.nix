# Project-specific helper functions, exposed as `flake.lib` and aliased to the
# `lib'` module argument (via `_module.args`) for ergonomic access everywhere.
{ lib, config, ... }:
{
  _module.args.lib' = config.flake.lib;

  flake.lib = rec {
    systemInput =
      {
        inputs,
        name,
        channel,
        os,
      }:
      inputs."${name}-${os}-${channel}" or inputs.${name};
    systemOs = system: lib.last (lib.splitString "-" system);
    systemArch = system: lib.head (lib.splitString "-" system);
    # compare two lists irrespective of order
    setEqual = list1: list2: (lib.naturalSort list1) == (lib.naturalSort list2);
    # return [ path ] if it exists, otherwise [ ]
    optionalPath = path: if builtins.pathExists path then [ path ] else [ ];
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
    mkVimKeymap =
      {
        raw,
        prefix ? "",
        suffix ? "",
        mode ? "n",
      }:
      attrs:
      attrs
      // {
        action =
          if raw then
            { __raw = "function() ${prefix}${attrs.action}${suffix} end"; }
          else
            "<cmd>${prefix}${attrs.action}${suffix}<CR>";
        mode = attrs.mode or mode;
      };
    mkVimKeymaps = opts: values: map (mkVimKeymap opts) values;

    # Render markdown with optional JSON frontmatter (a valid subset of YAML).
    mkMarkdown =
      {
        metadata ? { },
        body ? "",
      }:
      if metadata == { } then
        body
      else
        ''
          ---
          ${lib.strings.toJSON metadata}
          ---

          ${body}
        '';

    mdFormat = lib.types.submodule (
      { config, ... }:
      {
        options = {
          metadata = lib.mkOption {
            type =
              # https://github.com/NixOS/nixpkgs/blob/130323cfcfdfe3a28da4f9ca4593f053f07c7487/pkgs/pkgs-lib/formats.nix#L125C7-L141C19
              with lib.types;
              let
                valueType =
                  nullOr (oneOf [
                    bool
                    int
                    float
                    str
                    path
                    (attrsOf valueType)
                    (listOf valueType)
                  ])
                  // {
                    description = "JSON value";
                  };
              in
              valueType;
            default = { };
            description = "Frontmatter for the markdown file, written as JSON (a valid subset of YAML).";
          };
          body = lib.mkOption {
            type = lib.types.lines;
            default = "";
            description = "Markdown content for the file.";
          };
          text = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
          };
        };
        config.text = mkMarkdown { inherit (config) metadata body; };
      }
    );

    # Symlink a file to its live location in the checked-out config repo
    # (`config.custom.configPath`) rather than the read-only store, so edits take
    # effect without a rebuild. `value` is a path within this repo; its prefix
    # relative to the repo root is reused under the checkout.
    # https://github.com/ncfavier/config/blob/bfc59fe3febc7a389105d05141215ca725bf7a9f/modules/nix.nix#L64-L68
    mkMutableSymlink =
      { config, value }:
      config.lib.file.mkOutOfStoreSymlink (
        config.custom.configPath + lib.removePrefix (toString ../..) (toString value)
      );

    # Home-manager activation entry that installs writable copies of files after
    # linkGeneration. Use for programs that rewrite their own config and choke on
    # read-only store symlinks: the writable copy lets them work, while our
    # declared content is restored on every rebuild. `coreutils` (hence `install`)
    # is always on the activation PATH. `hmLib` is `lib.hm` (for `dag.entryAfter`);
    # `files` is a list of { source; target; mode ? "600"; }.
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
      mkMutableFiles {
        inherit config;
        files = [ { inherit source target mode; } ];
      };

    # import every `final: prev: -> attrset` overlay fragment in `dir` and merge them at the top level
    importOverlays =
      dir: final: prev:
      let
        filterPath =
          name: type:
          !lib.hasPrefix "_" name && type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix";
        files = builtins.attrNames (lib.filterAttrs filterPath (builtins.readDir dir));
      in
      lib.mergeAttrsList (map (name: import (dir + "/${name}") final prev) files);
  };
}
