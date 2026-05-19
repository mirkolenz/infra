{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    ;

  tomlFormat = pkgs.formats.toml { };

  cfg = config.programs.op;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.op = {
    enable = mkEnableOption "1password";

    package = mkPackageOption pkgs "_1password-cli" { nullable = true; };

    sshAgent = {
      enable = mkEnableOption "1password ssh agent";
      socket = mkOption {
        type = lib.types.str;
        default =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
          else
            "~/.1password/agent.sock";
        description = ''
          Value used verbatim as `IdentityAgent` in the user's SSH config.
        '';
      };
      settings = mkOption {
        type = tomlFormat.type;
        default = { };
        description = ''
          Configuration written to
          {file}`$XDG_CONFIG_HOME/1password/ssh/agent.toml`.
          See <https://developer.1password.com/docs/ssh/agent/config>
          for more information.
        '';
      };
    };

    gitSign = {
      enable = mkEnableOption "1password ssh-based git commit signing";
      key = mkOption {
        type = lib.types.str;
        description = ''
          Public SSH key used to sign git commits.
          The corresponding private key must be available through the
          1password ssh agent.
        '';
      };
      program = mkOption {
        type = lib.types.path;
        default =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
          else
            "${pkgs._1password-gui}/share/1password/op-ssh-sign";
        description = "Path to the `op-ssh-sign` program invoked by git.";
      };
    };
  };

  #
  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    programs.ssh = lib.mkIf cfg.sshAgent.enable {
      includes = [
        "~/.ssh/1password/config"
      ];
      settings."*".IdentityAgent = ''"${cfg.sshAgent.socket}"'';
    };

    xdg.configFile."1password/ssh/agent.toml" = lib.mkIf cfg.sshAgent.enable {
      source = tomlFormat.generate "1password-ssh-agent.toml" cfg.sshAgent.settings;
    };

    programs.git.signing = lib.mkIf cfg.gitSign.enable {
      format = "ssh";
      key = cfg.gitSign.key;
      signer = cfg.gitSign.program;
      signByDefault = true;
    };
  };
}
