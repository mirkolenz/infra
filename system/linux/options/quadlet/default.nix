{
  lib,
  lib',
  config,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    ;
  pd = config.virtualisation.quadlet.proxy.primaryDomain;
in
{
  imports = lib'.flocken.getModules ./.;
  options.virtualisation.quadlet.containers = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        let
          rp = config.virtualHost.reverseProxy;
        in
        {
          options.virtualHost = mkOption {
            default = { };
            type = types.submodule ./_vhost.nix;
          };
          config = {
            virtualHost.hostName = lib.mkDefault (if pd != null then "${name}.${pd}" else name);
            containerConfig.PublishPort = lib.mkIf (rp.publishPort != null) [
              "127.0.0.1:${toString rp.publishPort}:${toString rp.containerPort}"
            ];
          };
        }
      )
    );
  };
}
