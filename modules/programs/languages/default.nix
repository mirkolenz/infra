# The languages of every editor, a generic module with the options of options/shared/_editors.
{ config, ... }:
let
  module = config.flake.modules.generic.languages;
in
{
  flake.modules = {
    homeManager.default.imports = [ module ];
    nixvim.default.imports = [ module ];
  };
}
