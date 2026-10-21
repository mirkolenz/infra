{ config, ... }:
{
  imports = [ ../shared/_claude-code.nix ];

  config.environment.etc."claude-code/managed-settings.json" = {
    source = config.programs.claude-code.managedSettings;
    mode = "0644";
  };
}
