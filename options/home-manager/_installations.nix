# Module adding `installations` to `programs.${program}`, further installations of an
# agent in config directories of their own, and thus with logins of their own. Each
# gets the regular settings file with its overrides merged on top, the `sharedEntries`
# of the regular config directory as symlinks, and a wrapper pointing `envVar` at its
# directory. `settingsFile` is the `home.file` attribute upstream writes the settings to,
# replaced by writable copies if `mutable`.
{
  program,
  package,
  envVar,
  format,
  settingsFile,
  sharedEntries,
  example,
  mutable ? false,
}:
{
  config,
  pkgs,
  lib,
  lib',
  ...
}:
let
  cfg = config.programs.${program};

  exe = baseNameOf (lib.getExe package);
  settings = config.home.file.${settingsFile}.source;
  settingsDir = dirOf settingsFile;
  dir =
    if lib.hasPrefix "/" settingsDir then
      settingsDir
    else
      "${config.home.homeDirectory}/${settingsDir}";

  # yj names formats by their initial
  flag =
    {
      json = "j";
      toml = "t";
    }
    .${format};

  # merged recursively, replacing lists like `lib.recursiveUpdate`
  mergeSettings =
    name: overrides:
    if overrides == { } then
      settings
    else
      pkgs.runCommandLocal "${exe}-${name}.${format}"
        {
          nativeBuildInputs = with pkgs; [
            jq
            yj
          ];
          overrides = builtins.toJSON overrides;
          passAsFile = [ "overrides" ];
        }
        ''
          yj -${flag}j < ${settings} \
            | jq --slurp '.[0] * .[1]' - "$overridesPath" \
            | yj -j${flag} > "$out"
        '';

  named = lib.mapAttrs (name: overrides: {
    dir = "${dir}-${name}";
    settings = mergeSettings name overrides;
  }) cfg.installations;
  all = named // {
    default = { inherit dir settings; };
  };

  optionType = lib.types.attrsOf (pkgs.formats.${format} { }).type;
in
{
  options.programs.${program} = {
    installations = lib.mkOption {
      # `default` names the regular installation, configured through `settings`
      type = lib.types.addCheck optionType (installations: !(installations ? default)) // {
        description = "${optionType.description} without a `default` attribute";
      };
      default = { };
      inherit example;
      description = ''
        Further installations keyed by name, each holding settings merged recursively
        over the regular ones, with lists replaced. An installation gets a config
        directory of its own, and thus a login of its own, reached through a wrapper
        named after the executable and the installation.
      '';
    };

    configDirs = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.mapAttrsToList (_name: installation: installation.dir) all;
      readOnly = true;
      internal = true;
      description = "Config directories of every installation, the regular one included.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.file = lib.concatMapAttrs (
          _name: installation:
          lib.genAttrs' sharedEntries (
            entry:
            lib.nameValuePair "${installation.dir}/${entry}" {
              source = config.lib.file.mkOutOfStoreSymlink "${dir}/${entry}";
            }
          )
        ) named;

        home.packages = lib.mapAttrsToList (
          name: installation:
          pkgs.writeShellScriptBin "${exe}-${name}" ''
            export ${envVar}=${installation.dir}
            exec ${lib.getExe package} "$@"
          ''
        ) named;
      }
      (
        if mutable then
          {
            home.file.${settingsFile}.enable = lib.mkForce false;

            home.activation."${program}-settings" = lib'.mkMutableFiles {
              inherit config;
              files = lib.mapAttrsToList (_name: installation: {
                source = installation.settings;
                target = "${installation.dir}/${baseNameOf settingsFile}";
              }) all;
            };
          }
        else
          {
            home.file = lib.concatMapAttrs (_name: installation: {
              "${installation.dir}/${baseNameOf settingsFile}".source = installation.settings;
            }) named;
          }
      )
    ]
  );
}
