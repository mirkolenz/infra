# Wires the nixvim.default bucket: the `lib'` module argument and the shared +
# nixvim option declarations. All `vim/*` feature files merge into
# flake.modules.nixvim.default.
{ inputs, lib', ... }:
{
  flake.modules.nixvim.default =
    { pkgs, ... }:
    {
      _module.args = { inherit lib'; };
      imports = [
        (inputs.import-tree ../../options/shared)
        (inputs.import-tree ../../options/nixvim)
      ];

      package = pkgs.neovim-nightly;
      viAlias = true;
      vimAlias = true;
      # the man page renders every nixvim option, the largest single cost of the build
      enableMan = false;

      # every plugin is Lua and the language servers bundle their runtimes,
      # so none of the remote plugin providers is needed
      withNodeJs = false;
      withPerl = false;
      withPython3 = false;
      withRuby = false;
    };
}
