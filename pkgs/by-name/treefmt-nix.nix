# The repository formatter, built here so the flake's `formatter`, every home and the hooks of the
# coding agents share one evaluation of treefmt-nix, exposed as `passthru.config`.
# Its formatters are those of the languages of the editors, see options/treefmt/editors.nix.
# https://github.com/NixOS/nixpkgs/blob/master/ci/default.nix
{
  inputs,
  pkgs,
}:
let
  inherit
    (inputs.treefmt-nix.lib.evalModule pkgs {
      imports = [
        ../../options/treefmt/editors.nix
        inputs.self.modules.generic.languages
      ];
      custom.features.extras.enable = true;
      projectRootFile = "flake.nix";
    })
    config
    ;
in
config.build.wrapper.overrideAttrs { passthru = { inherit config; }; }
