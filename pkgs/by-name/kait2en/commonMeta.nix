# Shared by every package in the scope, a T2 Mac is always Intel.
{ lib }:
{
  homepage = "https://github.com/kaiT2en/KaiT2en-Fedora";
  license = lib.licenses.gpl3Plus;
  maintainers = with lib.maintainers; [ mirkolenz ];
  platforms = [ "x86_64-linux" ];
  # Only used on a T2 Mac.
  hydraPlatforms = [ ];
}
