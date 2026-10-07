{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.openssh;

  # mirrors nixos/modules/services/networking/ssh/sshd.nix without its typed options,
  # whose NixOS defaults would override those of macOS
  settingsFormat =
    let
      # reports boolean as yes / no
      mkValueString =
        v:
        if lib.isInt v then
          toString v
        else if lib.isString v then
          v
        else if lib.isPath v then
          v
        else if true == v then
          "yes"
        else if false == v then
          "no"
        else
          throw "unsupported type ${builtins.typeOf v}: ${(lib.generators.toPretty { }) v}";

      base = pkgs.formats.keyValue {
        mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } " ";
      };
      commaSeparated = [
        "Ciphers"
        "KexAlgorithms"
        "Macs"
      ];
      spaceSeparated = [
        "AcceptEnv"
        "AuthorizedKeysFile"
        "AllowGroups"
        "AllowUsers"
        "DenyGroups"
        "DenyUsers"
      ];
    in
    {
      inherit (base) type;
      generate =
        name: value:
        let
          transformedValue = lib.mapAttrs (
            key: val:
            if lib.isList val then
              if lib.elem key commaSeparated then
                lib.concatStringsSep "," val
              else if lib.elem key spaceSeparated then
                lib.concatStringsSep " " val
              else
                throw "list value for unknown key ${key}: ${(lib.generators.toPretty { }) val}"
            else
              val
          ) value;
        in
        base.generate name transformedValue;
    };

  configFile = settingsFormat.generate "sshd.conf-settings" (
    lib.filterAttrs (_: v: v != null) cfg.settings
  );
in
{
  options.services.openssh.settings = lib.mkOption {
    description = "Configuration for `sshd_config(5)`.";
    default = { };
    example = lib.literalExpression ''
      {
        UseDns = true;
        PasswordAuthentication = false;
      }
    '';
    type = lib.types.submodule {
      freeformType = settingsFormat.type;
    };
  };

  # sorts before the extraConfig in 100-nix-darwin.conf, as in the NixOS sshd_config
  config.environment.etc."ssh/sshd_config.d/100-nix-darwin-settings.conf".source = configFile;
}
