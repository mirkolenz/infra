# Wires the nixvim.default bucket: the `_module.args` bridge and the shared +
# nixvim option declarations. All `vim/*` feature files merge into
# flake.modules.nixvim.default.
{ inputs, lib', ... }:
{
  flake.modules.nixvim.default = {
    _module.args = {
      inherit inputs lib';
    };
    imports = [
      (inputs.import-tree ../../options/shared)
      (inputs.import-tree ../../options/nixvim)
    ];

    viAlias = true;
    vimAlias = true;
    # the man page renders every nixvim option, the largest single cost of the build
    enableMan = false;

    withNodeJs = true;
    withPython3 = true;
    withRuby = true;
    withPerl = true;
  };
}
