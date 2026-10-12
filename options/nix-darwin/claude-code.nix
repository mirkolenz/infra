# Claude Code reads its managed settings on macOS from `/Library/Application Support/ClaudeCode`,
# which nix-darwin cannot manage, so every activation links that directory to `/etc/claude-code`.
# A directory that MDM or an installer created stays untouched.
{ config, lib, ... }:
let
  target = lib.escapeShellArg "/Library/Application Support/ClaudeCode";
in
{
  imports = [ ../shared/_claude-code.nix ];

  config.system.activationScripts.postActivation.text =
    lib.mkIf (config.programs.claude-code.managedSettings != { })
      /* bash */ ''
        if [[ -L ${target} || ! -e ${target} ]]; then
          ln -sfn /etc/claude-code ${target}
        else
          echo "warning: not linking ${target} to /etc/claude-code, since it is a directory" >&2
        fi
      '';
}
