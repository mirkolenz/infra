# Wires the nixvim.default bucket: the `_module.args` bridge and nixvim option
# declarations. All `vim/*` feature files merge into flake.modules.nixvim.default.
{ inputs, lib', ... }:
{
  flake.modules.nixvim.default = {
    _module.args = {
      inherit inputs lib';
    };
    imports = [ (inputs.import-tree ../../options/nixvim) ];

    viAlias = true;
    vimAlias = true;
    enableMan = true;

    withNodeJs = true;
    withPython3 = true;
    withRuby = true;
    withPerl = true;
  };
}
