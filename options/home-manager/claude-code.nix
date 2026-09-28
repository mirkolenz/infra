# Extends home-manager's `programs.claude-code` with installations for further accounts.
# Installations differ only in settings and login, the latter kept in `.claude.json`
# and a keychain entry that both follow `CLAUDE_CONFIG_DIR`.
# https://github.com/nix-community/home-manager/blob/master/modules/programs/claude-code
{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.claude-code;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  imports = [
    (import ./_installations.nix {
      program = "claude-code";
      package = cfg.finalPackage;
      envVar = "CLAUDE_CONFIG_DIR";
      format = "json";
      settingsFile = "${cfg.configDir}/settings.json";
      sharedEntries = [
        "CLAUDE.md"
        "skills"
      ];
      example.work.forceLoginOrgUUID = "00000000-0000-0000-0000-000000000000";
    })
  ];
}
