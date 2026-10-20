{ lib', ... }:
{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      agents = config.programs.agents;
      cfg = config.programs.pi-coding-agent;
    in
    lib.mkIf agents.enable {
      programs.pi-coding-agent = {
        enable = true;
        package = pkgs.pi-agent-bin;
        inherit (agents) context;
        # https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/settings.md
        settings.enableInstallTelemetry = false;
      };
      # the upstream module has no option for the skills or the version check
      home.file = lib'.mkAgentSkills ".pi/agent/skills" agents.skills;
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";
      programs.agents = {
        # pi has no sandbox of its own and no flag for extra directories
        harnesses.pi = {
          launchers.pi = cfg.package;
          # the sessions and the provider logins
          paths.write = [ cfg.configDir ];
          paths.read = [
            "${cfg.configDir}/AGENTS.md"
            "${cfg.configDir}/settings.json"
            "${cfg.configDir}/skills"
          ];
          # the subscription providers that the claude and codex harnesses use as well
          domains = [
            "api.anthropic.com"
            "claude.ai"
            "platform.claude.com"
            "auth.openai.com"
            "chatgpt.com"
          ];
        };
        # The project settings and resources load only after the project is trusted.
        sandbox.workspace.read = [ ".pi" ];
      };
    };
}
