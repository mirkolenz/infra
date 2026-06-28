{
  configurations.nixos.macbook-161.module =
    {
      pkgs,
      inputs,
      lib,
      config,
      ...
    }:
    let
      # https://github.com/kholia/OSX-KVM/blob/4c378a4b5e0b219783683012bec680325eb40719/fetch-macOS-v2.py#L547
      fetchmacos =
        pkgs.callPackage "${inputs.nixos-hardware}/apple/t2/pkgs/brcm-firmware/fetchmacos.nix"
          { };
      firmware = (
        pkgs.callPackage "${inputs.nixos-hardware}/apple/t2/pkgs/brcm-firmware" {
          version = "sonoma";
        }
      );
      patchedFirmware = firmware.overrideDerivation (old: {
        version = "tahoe";
        # nix build .#nixosConfigurations.macbook-161.config.hardware.apple-t2-firmware.package
        src = fetchmacos {
          name = "tahoe";
          boardId = "Mac-CFF7D910A743CAAF";
          mlb = "00000000000000000";
          osType = "latest";
          hash = "sha256-p92fXePpaQ0+7CKpy/t+66B5nmOTmSCFWUw4+6aKq0A=";
        };
      });
      cfg = config.hardware.apple-t2-firmware;
    in
    {
      options.hardware.apple-t2-firmware = {
        enable = lib.mkEnableOption "T2 Mac firmware";
        package = lib.mkOption {
          type = lib.types.package;
          default = patchedFirmware;
        };
      };
      config = lib.mkIf cfg.enable {
        hardware.firmware = [ cfg.package ];
      };
    };
}
