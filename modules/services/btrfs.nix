# Monthly scrub of every btrfs filesystem, deduplicated by device upstream.
{
  flake.modules.nixos.base =
    { lib, config, ... }:
    lib.mkIf (lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems)) {
      services.btrfs.autoScrub.enable = true;
      # skips the run on battery, machines without one count as on AC power
      systemd.services."btrfs-scrub@".unitConfig.ConditionACPower = true;
    };
}
