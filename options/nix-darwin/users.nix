{ lib, ... }:
let
  systemUsers = {
    _llamacpp = 551;
  };
in
{
  ids.uids = systemUsers;
  ids.gids = systemUsers;
  users.knownUsers = lib.attrNames systemUsers;
  users.knownGroups = lib.attrNames systemUsers;
}
