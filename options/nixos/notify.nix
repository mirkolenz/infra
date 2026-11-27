# Push notifications via ntfy. The template `notify@<unit>.service` publishes the result
# and the last log lines of the unit, and a top-level drop-in adds it as `OnFailure=`
# to every system service. Other units may use it as `onSuccess` too.
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.custom.notify;
in
{
  options.custom.notify = {
    enable = lib.mkEnableOption "push notifications about failed services";
    server = mkOption {
      type = types.str;
      example = "https://ntfy.example.com";
      description = "Base URL of the ntfy server, which has to allow anonymous publishing to the topic.";
    };
    topic = mkOption {
      type = types.str;
      description = "Topic the notifications are published to.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The unit builder merges the drop-in directories of packages, but not those of `systemd.units`,
    # so a package provides the top-level drop-in, which other modules may extend.
    systemd.packages = [
      (pkgs.writeTextDir "etc/systemd/system/service.d/notify.conf" (
        utils.systemdUtils.lib.settingsToSections {
          Unit.OnFailure = "notify@%n.service";
        }
      ))
    ];

    # Masks the top-level drop-in, so a failed notification does not trigger another one.
    systemd.units."notify@.service.d/notify.conf".enable = false;

    systemd.services."notify@" = {
      description = "Push notification about %i";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [
        config.systemd.package
        pkgs.jq
        pkgs.curl
      ];
      scriptArgs = "%i";
      # jq truncates by code points, ntfy turns messages above 4K into attachments.
      # The retries back off exponentially for about 4 minutes.
      script = ''
        unit=$1
        result=$(systemctl show --property=Result --value "$unit")
        journalctl --unit="$unit" --invocation=0 --lines=10 --output=cat --no-pager |
          jq --raw-input --slurp \
            --arg topic ${lib.escapeShellArg cfg.topic} \
            --arg title "$unit: $result on ${config.networking.hostName}" \
            --arg result "$result" \
            '{
              topic: $topic,
              title: $title,
              message: .[-3000:],
              priority: (if $result == "success" then 3 else 4 end),
              tags: [if $result == "success" then "white_check_mark" else "rotating_light" end]
            }' |
          curl --fail-with-body --silent --show-error \
            --retry 8 --retry-all-errors \
            --json @- ${lib.escapeShellArg cfg.server}
      '';
      # A failed instance would keep the failed unit loaded through `OnFailure=`,
      # which blocks a transient unit of the same name, such as of nixos-rebuild.
      unitConfig.CollectMode = "inactive-or-failed";
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        SupplementaryGroups = [ "systemd-journal" ];
      };
    };
  };
}
