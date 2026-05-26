{ lib', lib, ... }:
{
  imports = lib'.flocken.getModules ./.;

  time.timeZone = "Europe/Berlin";

  environment = {
    variables = {
      PAGER = "less";
    };
    defaultPackages = lib.mkForce [ ];
  };
}
