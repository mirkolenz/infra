{
  flake.modules.homeManager.default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    lib.mkIf config.custom.features.withOptionals {
      programs.mcp = {
        enable = true;
        servers = {
          nixos = {
            command = lib.getExe pkgs.mcp-nixos;
            # Codex-only: auto-approve this server's tools; ignored by other MCP clients
            default_tools_approval_mode = "approve";
          };
        };
      };
      # Claude bundles MCP servers into the generated "claude-code-home-manager" plugin,
      # so its tools are namespaced as plugin_<plugin>_<server>; auto-allow them here to
      # keep all MCP approval config in one place (merges with the claude.nix allow list)
      programs.claude-code.settings.permissions.allow = [
        "mcp__plugin_claude-code-home-manager_nixos"
      ];
    };
}
