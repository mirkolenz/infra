{ lib, ... }:
let
  systemUsers = {
    _llamacpp = 551;
    _ollama = 552;
  };
in
{
  ids.uids = systemUsers;
  ids.gids = systemUsers;
  users.knownUsers = lib.attrNames systemUsers;
  users.knownGroups = lib.attrNames systemUsers;
}
