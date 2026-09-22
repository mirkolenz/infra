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
    # unstable nixpkgs for `system`, as the flake input rather than its store
    # path: nix-darwin reads `rev` off it for `system.nixpkgsRevision`.
    nixpkgsInput =
      { inputs, system }:
      systemInput {
        inherit inputs;
        name = "nixpkgs";
        channel = "unstable";
        os = systemOs system;
      };
    systemOs = system: lib.last (lib.splitString "-" system);
    # return [ path ] if it exists, otherwise [ ]
    optionalPath = path: if lib.pathExists path then [ path ] else [ ];
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

    # `lib.hm.strings.isPathLike`, inlined because `lib.hm` only exists inside a
    # home-manager evaluation: a value home-manager links rather than writes.
    # https://github.com/nix-community/home-manager/blob/master/modules/lib/strings.nix
    isPathLike =
      content:
      lib.isPath content
      || lib.isDerivation content
      || (lib.isString content && lib.hasPrefix "${builtins.storeDir}/" content);

    # `home.file` entry for the value of an agent option that is either content or a
    # file to link, the way the claude-code, codex, and opencode modules read theirs.
    # https://github.com/nix-community/home-manager/blob/master/modules/programs/claude-code/lib.nix
    mkAgentFile = content: if isPathLike content then { source = content; } else { text = content; };

    # `home.file` entries placing the value of `programs.agents.skills` in `dir`. A
    # directory is linked as a whole, an attribute set becomes one entry per skill,
    # where a directory is again linked as a whole and everything else is the skill's
    # `SKILL.md`. Both stay real directories, which lets an agent write its own skills
    # next to the managed ones. A store path that is only a string is taken for a file,
    # because telling it apart from a directory needs a builder, as upstream does it.
    # https://github.com/nix-community/home-manager/blob/master/modules/programs/claude-code/lib.nix
    mkAgentSkills =
      dir: skills:
      if isPathLike skills then
        {
          ${dir} = {
            source = skills;
            recursive = true;
          };
        }
      else
        lib.concatMapAttrs (
          name: content:
          if lib.isPath content && lib.pathIsDirectory content then
            {
              "${dir}/${name}" = {
                source = content;
                recursive = true;
              };
            }
          else
            { "${dir}/${name}/SKILL.md" = mkAgentFile content; }
        ) skills;

    disableUpdateScript =
      pkg:
      pkg.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          updateScript = null;
        };
      });

    # `nix-update` resolves `attrPath` against the package set, so naming where the package
    # actually lives keeps it from selecting through a flattened set, which would force every
    # package just to answer one lookup.
    setUpdateScriptAttrPath =
      attrPath: pkg:
      pkg.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          updateScript =
            let
              script = old.passthru.updateScript or null;
            in
            if script == null then
              null
            else if lib.isAttrs script && !lib.isDerivation script then
              script // { inherit attrPath; }
            else
              {
                command = script;
                inherit attrPath;
              };
        };
      });

    # import and compose `final: prev: -> attrset` overlay fragments in the given order,
    # so that each fragment sees the preceding ones in its `prev`
    importOverlays = paths: lib.composeManyExtensions (map import paths);
  };
}
