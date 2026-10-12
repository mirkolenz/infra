# `programs.claude-code.managedSettings` for nix-darwin and NixOS, written to `/etc/claude-code`,
# where Claude Code looks for them on Linux.
# https://code.claude.com/docs/en/settings#settings-files
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude-code;
  jsonFormat = pkgs.formats.json { };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.claude-code.managedSettings = lib.mkOption {
    inherit (jsonFormat) type;
    default = { };
    example.permissions.disableBypassPermissionsMode = "disable";
    description = ''
      Managed settings of Claude Code, which win over every other settings file and hold
      the policies that only managed settings enforce, for the CLI and the desktop app alike.
      They live outside of the home directory, out of reach of users and agents.
    '';
  };

  config.environment.etc."claude-code/managed-settings.json" = lib.mkIf (cfg.managedSettings != { }) {
    source = jsonFormat.generate "claude-code-managed-settings.json" cfg.managedSettings;
  };
}
