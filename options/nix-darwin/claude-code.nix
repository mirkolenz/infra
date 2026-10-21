# Claude Code reads its managed settings on macOS from `/Library/Application Support/ClaudeCode`,
# which nix-darwin cannot manage, so every activation recreates it with a copy of the settings.
{ config, lib, ... }:
let
  target = lib.escapeShellArg "/Library/Application Support/ClaudeCode";
in
{
  imports = [ ../shared/_claude-code.nix ];

  config.system.activationScripts.postActivation.text = /* bash */ ''
    rm -rf ${target}
    install -Dm0644 ${config.programs.claude-code.managedSettings} ${target}/managed-settings.json
  '';
}
