# Formats the files the coding agents edit with `agent-format`, see pkgs/by-name/agent-format.
# Only harnesses with native support are wired up: Claude Code and Codex through their
# hooks, opencode through its formatters.
{ lib, pkgs, ... }:
let
  command = lib.getExe pkgs.agent-format;

  hook = timeout: [
    {
      type = "command";
      command = "${command} hook";
      inherit timeout;
    }
  ];

  # Codex edits through patches, which `Edit` and `Write` alias.
  hooks = {
    PostToolUse = [
      {
        matcher = "Edit|Write";
        hooks = hook 60;
      }
    ];
    Stop = [ { hooks = hook 120; } ];
  };
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  config.programs = {
    claude-code.settings.hooks = hooks;
    codex.hooks = hooks;
    # opencode matches the file extension only.
    opencode.settings.formatter.agent-format = {
      command = [
        command
        "files"
        "$FILE"
      ];
      inherit (pkgs.agent-format) extensions;
    };
  };
}
