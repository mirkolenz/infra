{
  lib,
  mkApp,
  mkGitHubBinary,
}:
lib.extendMkDerivation {
  constructDrv = mkApp;
  excludeDrvArgNames = [
    "ghBin"
  ];
  extendDrvArgs =
    finalAttrs:
    args@{ ghBin, ... }:
    let
      ghDrv = mkGitHubBinary ghBin;
    in
    {
      pname = args.pname or ghDrv.pname;
      version = args.version or ghDrv.version;
      srcs = args.srcs or ghDrv.srcs;
      passthru = (ghDrv.passthru or { }) // (args.passthru or { });
      meta = (ghDrv.meta or { }) // (args.meta or { });
    };
}
