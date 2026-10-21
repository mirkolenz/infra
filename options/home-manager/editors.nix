# Puts the active servers and tools of options/shared/_editors on the PATH,
# for the command line and editors without an integration.
{ config, lib, ... }:
let
  inherit (config.custom) active;
in
{
  meta.maintainers = with lib.maintainers; [ mirkolenz ];

  imports = [ ../shared/_editors ];

  config.home.packages = map (entry: entry.package) (
    lib.attrValues active.servers ++ lib.attrValues active.tools
  );
}
