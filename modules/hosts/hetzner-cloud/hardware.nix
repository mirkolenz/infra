{
  configurations.nixos.hetzner-cloud.module =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    };
}
