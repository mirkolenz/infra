{ lib, ... }:
let
  inherit (lib)
    types
    mkOption
    ;
in
{
  options = {
    services.caddy.virtualHosts = mkOption {
      type = types.attrsOf (types.submodule ./_vhost.nix);
    };
  };
}
