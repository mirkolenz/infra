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

    # https://github.com/ncfavier/config/blob/bfc59fe3febc7a389105d05141215ca725bf7a9f/modules/nix.nix#L64-L68
    mkMutableSymlink =
      { config, value }:
      config.hm.lib.file.mkOutOfStoreSymlink (
        config.custom.configPath + lib.removePrefix (toString ../..) (toString value)
      );

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
