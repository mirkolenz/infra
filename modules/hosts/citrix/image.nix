# Convert the host's disk image (system.build.image) into a fixed VHD for the
# Citrix Hypervisor / XCP-ng admin to import, exposed as a build attribute next
# to the stock builders (system.build.image, .diskoImages, .toplevel, ...):
#   nix build .#nixosConfigurations.citrix.config.system.build.image-vhd
{
  configurations.nixos.citrix.module =
    { config, pkgs, ... }:
    {
      system.build.image-vhd =
        pkgs.runCommand "${config.image.baseName}-vhd" { nativeBuildInputs = [ pkgs.qemu-utils ]; }
          ''
            mkdir -p "$out"
            qemu-img convert -f ${config.image.format} -O vpc -o subformat=fixed,force_size=on \
              ${config.system.build.image}/${config.image.fileName} "$out/${config.image.baseName}.vhd"
          '';
    };
}
