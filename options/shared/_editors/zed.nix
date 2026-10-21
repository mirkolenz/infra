# The options of Zed, whose integration is options/home-manager/zed.nix.
{ lib, jsonType, ... }:
let
  inherit (lib) mkOption types;
in
{
  language.options.editors.zed = {
    names = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Zed languages of the language.";
    };

    extensions = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        Zed extensions that provide the language, installed along with Zed even while the
        language is disabled.
      '';
    };
  };

  server =
    { name, config, ... }:
    {
      options.editors.zed = {
        name = mkOption {
          type = types.str;
          default = name;
          defaultText = lib.literalMD "the attribute name";
          description = "Name by which Zed or its extension knows the language server.";
        };

        extension = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "harper";
          description = "Zed extension that only provides the language server, installed along with it.";
        };

        settings = mkOption {
          type = jsonType;
          default = config.settings;
          defaultText = lib.literalExpression "settings";
          description = "Workspace configuration for Zed, whose integrations of some servers add the section themselves.";
        };
      };
    };

  tool.options.editors.zed.codeAction = mkOption {
    type = with types; nullOr str;
    default = null;
    example = "source.fixAll.ruff";
    description = "Code action of a language server that Zed runs in place of the tool.";
  };
}
