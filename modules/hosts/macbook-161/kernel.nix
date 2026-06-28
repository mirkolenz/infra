{
  configurations.nixos.macbook-161.module =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # https://github.com/t2linux/linux-t2-patches
      # nix run .#t2-updater -- --branch main ./modules/hosts/macbook-161/kernel.json
      patchset = lib.fromJSON (lib.readFile ./kernel.json);
    in
    {
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_7_1;
      boot.kernelPatches = [
        {
          # https://github.com/NixOS/nixos-hardware/blob/master/apple/t2/pkgs/linux-t2/generic.nix
          name = "t2-config";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            APPLE_BCE = module;
            APPLE_GMUX = module;
            APFS_FS = module;
            BRCMFMAC = module;
            BT_BCM = module;
            BT_HCIBCM4377 = module;
            BT_HCIUART_BCM = yes;
            BT_HCIUART = module;
            HID_APPLETB_BL = module;
            HID_APPLETB_KBD = module;
            HID_APPLE = module;
            HID_MAGICMOUSE = module;
            DRM_APPLETBDRM = module;
            HID_SENSOR_ALS = module;
            SND_PCM = module;
            STAGING = yes;
          };
        }
      ]
      ++ map (
        { name, hash }:
        {
          inherit name;
          patch = pkgs.fetchurl {
            inherit name hash;
            url = patchset.base_url + name;
          };
        }
      ) patchset.patches;
    };
}
