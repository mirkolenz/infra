# Shared by every package in the scope: they all come out of the one upstream
# tree pinned in `modules.nix`, and a T2 Mac is always Intel.
{ lib }:
{
  homepage = "https://github.com/kaiT2en/KaiT2en-Fedora";
  license = lib.licenses.gpl3Plus;
  maintainers = with lib.maintainers; [ mirkolenz ];
  platforms = [ "x86_64-linux" ];
  # Only used on a T2 Mac, and a bump rebuilds the whole tree.
  hydraPlatforms = [ ];
}
