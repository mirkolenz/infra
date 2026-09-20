{
  flake.modules.homeManager.default =
    { lib, config, ... }:
    {
      programs.agents = {
        enable = true;
        instructions.source = ./AGENTS.md;
        skills = lib.mkIf config.custom.features.extras.enable (
          lib.concatMapAttrs (
            name: _:
            lib.optionalAttrs (lib.pathExists (./. + "/${name}/SKILL.md")) {
              ${name}.source = ./. + "/${name}";
            }
          ) (lib.readDir ./.)
        );
      };
    };
}
