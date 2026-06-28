{ ... }:
{
  perSystem =
    {
      system,
      config,
      lib,
      ...
    }:
    let
      isHydraTarget = value: lib.elem system (value.meta.hydraPlatforms or [ system ]);
      excluded = [
        "herdr"
        "hermes-agent"
        "mistral-vibe"
        "nixvim-default"
        "nixvim-minimal"
      ];
    in
    {
      checks = lib.filterAttrs (
        name: value: !(lib.elem name excluded) && isHydraTarget value
      ) config.packages;
    };
}
