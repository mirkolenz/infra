# `programs.claude-code.managedSettings` for nix-darwin and NixOS.
# Claude Code rejects a settings file reached through a link that leads outside its directory,
# so both platforms install a copy instead of a link into the store.
# https://code.claude.com/docs/en/settings#settings-files
{ lib, pkgs, ... }:
let
  jsonFormat = pkgs.formats.json { };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  options.programs.claude-code.managedSettings = lib.mkOption {
    inherit (jsonFormat) type;
    default = { };
    example.permissions.disableBypassPermissionsMode = "disable";
    apply = jsonFormat.generate "managed-settings.json";
    description = ''
      Managed settings of Claude Code, which win over every other settings file and hold
      the policies that only managed settings enforce, for the CLI and the desktop app alike.
      They live outside of the home directory, out of reach of users and agents.
    '';
  };
}
