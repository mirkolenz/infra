{ lib, ... }:
{
  options.custom.features.withOptionals = lib.mkEnableOption "optional plugins" // {
    default = true;
  };
}
