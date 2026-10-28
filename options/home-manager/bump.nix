# `bumpctl`, which updates the dependencies of the projects at or below the working directory
# and commits them per project and package manager.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.custom.bump;

  command = types.submodule {
    options = {
      args = mkOption {
        type = with types; listOf str;
        description = "Command line, in which `{message}` stands for the commit message.";
      };
      ifExists = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "vendor/modules.txt";
        description = "Path relative to the root of the project that has to exist for the command to run.";
      };
    };
  };
in
{
  options.custom.bump = mkOption {
    type = types.attrsOf (
      types.submodule {
        options = {
          lockfile = mkOption {
            type = types.str;
            description = "Path of the lockfile relative to the root of a project, which marks the projects using the package manager.";
          };
          excludes = mkOption {
            type = with types; listOf str;
            default = [ ];
            example = [ "**/testdata/**" ];
            description = "Glob patterns of the lockfiles that belong to no project of their own, such as test fixtures.";
          };
          pathspecs = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = "Git pathspecs of the files besides the lockfile and those of the range bumps that the package manager updates, relative to the root of a project, which may match no file.";
          };
          ranges = mkOption {
            type = types.nullOr (
              types.enum [
                "python"
                "node"
                "php"
                "actions"
                "nix"
              ]
            );
            default = null;
            description = "Ecosystem whose dependency ranges to bump ahead of the commands.";
          };
          commands = mkOption {
            type = types.listOf (types.coercedTo (with types; listOf str) (args: { inherit args; }) command);
            default = [ ];
            example = [
              [
                "uv"
                "lock"
                "--upgrade"
              ]
            ];
            description = ''
              Commands updating the dependencies of the project in the working directory, in order,
              given as command lines or with a condition, which may commit them with the message.
            '';
          };
          env = mkOption {
            type = with types; attrsOf str;
            default = { };
            description = "Environment variables of the commands.";
          };
        };
      }
    );
    default = { };
    description = ''
      Package managers of `bumpctl`, keyed by their scope in the commit messages,
      in addition to its built-in `nix` and `actions`, which they may replace.
    '';
  };

  config.home.packages = lib.mkIf config.custom.features.extras.enable [
    (pkgs.bumpctl.withConfig cfg)
  ];
}
