# The repository formatter, built here so the flake's `formatter`, every home and the hooks of the
# coding agents share one evaluation of treefmt-nix, exposed as `passthru.config`.
# Its formatters are those of the languages of the editors, see options/treefmt/editors.nix.
# The homes override the features with those of their host, see options/home-manager/treefmt.nix.
# https://github.com/NixOS/nixpkgs/blob/master/ci/default.nix
{
  inputs,
  pkgs,
  features ? {
    extras.enable = true;
  },
}:
let
  inherit
    (inputs.treefmt-nix.lib.evalModule pkgs {
      imports = [
        ../../options/treefmt/editors.nix
        inputs.self.modules.generic.languages
      ];
      custom.features = features;
      projectRootFile = "flake.nix";
    })
    config
    ;
in
config.build.wrapper.overrideAttrs { passthru = { inherit config; }; }
