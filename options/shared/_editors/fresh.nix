# The options of Fresh, whose integration is options/home-manager/fresh.nix.
{ lib, ... }:
{
  language =
    { name, ... }:
    {
      options.editors.fresh.names = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ name ];
        description = "Fresh languages of the language.";
      };
    };
}
