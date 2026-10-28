# Declarative default apps on macOS through utiluti.
# Since macOS 26.4, every changed type handler prompts for confirmation,
# so the package patches `utiluti manage` to only set the entries that differ from the current defaults.
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkPackageOption mkOption;

  cfg = config.programs.utiluti;

  # values are bundle identifiers, so assigning two apps to one handler is a definition conflict
  mkHandlersOption =
    example: description:
    mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      inherit example description;
    };

  writePlist = name: value: pkgs.writeText name (lib.generators.toPlist { escape = true; } value);

  typeFile = writePlist "utiluti-types.plist" (
    cfg.types // lib.mapAttrs' (ext: lib.nameValuePair "extension:${ext}") cfg.extensions
  );
  urlFile = writePlist "utiluti-urls.plist" cfg.schemes;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.utiluti = {
    enable = mkEnableOption "utiluti to manage default apps";

    package = mkPackageOption pkgs "utiluti" { };

    types = mkHandlersOption {
      "public.json" = "dev.zed.Zed";
    } "Bundle identifiers of the default apps, keyed by uniform type identifier.";

    extensions = mkHandlersOption { nix = "dev.zed.Zed"; } ''
      Bundle identifiers of the default apps, keyed by file extension,
      resolved to its type identifier during activation.
      Prefer {option}`programs.utiluti.types` for extensions with a declared type,
      and use this for extensions macOS only knows by a dynamic `dyn.*` identifier.
    '';

    schemes = mkHandlersOption { mailto = "com.apple.mail"; } ''
      Bundle identifiers of the default apps, keyed by URL scheme.
      Setting `http` also covers `https` and `public.html`.
    '';
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "programs.utiluti" pkgs lib.platforms.darwin)
    ];

    home.packages = [ cfg.package ];

    home.activation.utiluti = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe cfg.package} manage $VERBOSE_ARG --type-file ${typeFile} --url-file ${urlFile}
    '';
  };
}
