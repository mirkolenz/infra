# `custom.commands` for home-manager, nix-darwin and NixOS, which only differ in
# the option at `packagesPath` that receives the packaged scripts.
packagesPath:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  command = lib.types.submodule {
    # Arguments of `builder` besides the name and the script.
    freeformType = with lib.types; attrsOf anything;

    options = {
      text = lib.mkOption {
        type = lib.types.str;
        description = "The script.";
      };

      builder = lib.mkOption {
        type = lib.types.raw;
        # Adopts the `name: args: text` convention of `pkgs.writers.write*Bin`,
        # so that any of them can replace it.
        default =
          name: args: text:
          pkgs.writeShellApplication (args // { inherit name text; });
        defaultText = lib.literalExpression "pkgs.writeShellApplication";
        example = lib.literalExpression "pkgs.writers.writePython3Bin";
        description = ''
          Function `name: args: text` that packages the script,
          where `args` are all other attributes of the command.
        '';
      };
    };
  };
in
{
  options.custom.commands = lib.mkOption {
    # Lazy, so that commands can refer to each other without infinite recursion.
    type = with lib.types; lazyAttrsOf (coercedTo str (text: { inherit text; }) command);
    default = { };
    apply = lib.mapAttrs (
      name: args:
      args.builder name (removeAttrs args [
        "builder"
        "text"
      ]) args.text
    );
    example = lib.literalExpression ''
      {
        hello = "echo Hello";
        greet = {
          runtimeInputs = [ pkgs.cowsay ];
          text = "cowsay Hello";
        };
        fetch = {
          builder = pkgs.writers.writePython3Bin;
          libraries = [ pkgs.python3Packages.httpx ];
          text = "import httpx";
        };
      }
    '';
    description = ''
      Scripts by command name, installed into the environment,
      given as the script itself or as a command with the script as `text`.
      Reading the option yields the packages, so commands can refer to each other
      via `config.custom.commands.<name>`.
    '';
  };

  config = lib.setAttrByPath packagesPath (lib.attrValues config.custom.commands);
}
