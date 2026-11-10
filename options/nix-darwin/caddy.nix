# The NixOS `services.caddy` interface on darwin, reusing its virtual host options.
# TLS certificates from `security.acme` and the reload through the admin API are left out.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.caddy;
  inherit (lib) types;

  mkVHostConf = vhost: ''
    ${toString ([ vhost.hostName ] ++ vhost.serverAliases)} {
      ${lib.optionalString (vhost.listenAddresses != [ ]) "bind ${toString vhost.listenAddresses}"}
      ${lib.optionalString (vhost.logFormat != null) ''
        log {
          ${vhost.logFormat}
        }
      ''}
      ${vhost.extraConfig}
    }
  '';

  Caddyfile = pkgs.writeText "Caddyfile" ''
    {
      ${cfg.globalConfig}
    }
    ${cfg.extraConfig}
    ${lib.concatMapStringsSep "\n" mkVHostConf (lib.attrValues cfg.virtualHosts)}
  '';

  configFile = pkgs.runCommand "Caddyfile" { } ''
    cp --no-preserve=mode ${Caddyfile} $out
    ${lib.getExe cfg.package} fmt --overwrite $out
  '';
in
{
  options.services.caddy = {
    enable = lib.mkEnableOption "Caddy web server";

    package = lib.mkPackageOption pkgs "caddy" { };

    dataDir = lib.mkOption {
      type = types.str;
      default = "/private/var/lib/caddy";
      description = "The data directory of Caddy.";
    };

    logDir = lib.mkOption {
      type = types.str;
      default = "/private/var/log/caddy";
      description = "Directory of the service log and the access logs.";
    };

    logFormat = lib.mkOption {
      type = types.lines;
      default = "level ERROR";
      description = "Configuration of the default logger, see <https://caddyserver.com/docs/caddyfile/options#log>.";
    };

    globalConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Lines appended to the global options block of the `Caddyfile`.";
    };

    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = "Lines appended to the generated `Caddyfile`.";
    };

    virtualHosts = lib.mkOption {
      type = types.attrsOf (
        types.submodule (
          import "${pkgs.path}/nixos/modules/services/web-servers/caddy/vhost-options.nix" { inherit cfg; }
        )
      );
      default = { };
      description = "Virtual hosts served by Caddy.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (vhost: vhost.useACMEHost == null) (lib.attrValues cfg.virtualHosts);
        message = "services.caddy.virtualHosts.<name>.useACMEHost is unsupported on darwin.";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # Runs as root, since macOS reserves privileged ports on a specific address to it.
    # The admin API would let every local process reconfigure a root server,
    # and launchd restarts it on config changes anyway.
    # Caddy rotates its own log, launchd only captures output before the logger starts.
    services.caddy.globalConfig = ''
      admin off
      log {
        output file ${cfg.logDir}/caddy.log {
          roll_size 10MiB
          roll_keep 5
        }
        ${cfg.logFormat}
      }
    '';

    launchd.daemons.caddy = {
      environment = {
        HOME = cfg.dataDir;
        XDG_DATA_HOME = cfg.dataDir;
        XDG_CONFIG_HOME = cfg.dataDir;
      };
      command = lib.escapeShellArgs [
        (lib.getExe cfg.package)
        "run"
        "--config"
        configFile
        "--adapter"
        "caddyfile"
      ];
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ThrottleInterval = 10;
        WorkingDirectory = cfg.dataDir;
        StandardOutPath = "${cfg.logDir}/launchd.log";
        StandardErrorPath = "${cfg.logDir}/launchd.log";
      };
    };

    system.activationScripts.preActivation.text = ''
      mkdir -p "${cfg.dataDir}" "${cfg.logDir}"
    '';
  };
}
