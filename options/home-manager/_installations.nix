# Module adding `installations` to `programs.${program}`, installations of an agent
# in config directories of their own, and thus with logins of their own. Each gets
# the regular settings file with its overrides merged on top, the `sharedEntries`
# of the regular config directory as symlinks, and a wrapper pointing `envVar` at its
# directory. Without `defaultLauncher`, the regular config directory only serves as their base.
# `settingsFile` is the `home.file` attribute upstream writes the settings to, replaced by
# writable copies if `mutable`. `protectedEntries` are further entries of every config
# directory that agents may only read, like the managed ones.
{
  program,
  package,
  envVar,
  format,
  settingsFile,
  sharedEntries,
  protectedEntries ? [ ],
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

  # the name `lib.getExe` resolves, without the context of its store path
  exe = package.meta.mainProgram or (lib.getName package);
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
          overrides = lib.toJSON overrides;
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

  # completions delegate to those of the regular executable
  mkLauncher =
    name: installation:
    let
      cmd = "${exe}-${name}";
    in
    pkgs.symlinkJoin {
      name = cmd;
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      postBuild = ''
        makeBinaryWrapper ${lib.getExe package} $out/bin/${cmd} \
          --set ${envVar} ${installation.dir} \
          --set AGENTS_INSTALLATION ${name}
      '';
      paths = [
        (pkgs.writeTextDir "share/fish/vendor_completions.d/${cmd}.fish" ''
          complete --command ${cmd} --wraps ${exe}
        '')
        (pkgs.writeTextDir "share/zsh/site-functions/_${cmd}" ''
          #compdef ${cmd}
          words[1]=${exe}
          _normal
        '')
      ];
      # names the shell aliases of `programs.agents.harnesses.*.models`
      passthru.installation = name;
      meta.mainProgram = cmd;
    };

  installationLaunchers = lib.mapAttrs' (
    name: installation: lib.nameValuePair "${exe}-${name}" (mkLauncher name installation)
  ) named;

  # Shadows the regular executable that upstream installs.
  # Within an installation of any agent, it runs the installation of the same name,
  # through `PATH` to keep the sandbox of its launcher.
  dispatcher = lib.hiPrio (
    pkgs.writeShellScriptBin exe ''
      case "''${AGENTS_INSTALLATION-}" in
        ${lib.concatStringsSep "|" (lib.attrNames named)})
          exec ${exe}-"$AGENTS_INSTALLATION" "$@"
          ;;
      esac

      echo "${exe} has no default installation, use one of: ${toString (lib.attrNames installationLaunchers)}" >&2
      exit 1
    ''
  );

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
        Installations keyed by name, each holding settings merged recursively
        over the regular ones, with lists replaced. An installation gets a config
        directory of its own, and thus a login of its own, reached through a wrapper
        named after the executable and the installation.
      '';
    };

    defaultLauncher = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether the regular executable runs the regular installation, otherwise it runs
        the installation named by `AGENTS_INSTALLATION`, which every installation of every
        agent exports, and refuses to run without it.
      '';
    };

    configDirs = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.mapAttrsToList (_name: installation: installation.dir) all;
      readOnly = true;
      internal = true;
      description = "Config directories of every installation and the regular one they are based on.";
    };

    protectedPaths = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.concatMap (
        dir:
        map (entry: "${dir}/${entry}") ([ (baseNameOf settingsFile) ] ++ sharedEntries ++ protectedEntries)
      ) cfg.configDirs;
      readOnly = true;
      internal = true;
      description = ''
        The settings file, the shared entries and `protectedEntries` within the config directory
        of every installation, which agents may only read.
      '';
    };

    launchers = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = installationLaunchers // lib.optionalAttrs cfg.defaultLauncher { ${exe} = package; };
      readOnly = true;
      internal = true;
      description = "Executables of every installation by name, the regular one included with `defaultLauncher`.";
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

        home.packages =
          lib.attrValues installationLaunchers ++ lib.optional (!cfg.defaultLauncher) dispatcher;
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
