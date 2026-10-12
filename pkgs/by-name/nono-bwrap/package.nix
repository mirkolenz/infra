{
  lib,
  writers,
  replaceVars,
  python3Packages,
  bubblewrap,
  gitMinimal,
}:
(writers.writePython3Bin "nono-bwrap"
  {
    libraries = with python3Packages; [ typer ];
    doCheck = false;
  }
  (
    replaceVars ./script.py {
      bwrap = lib.getExe bubblewrap;
      git = lib.getExe gitMinimal;
    }
  )
).overrideAttrs
  (prev: {
    meta = prev.meta // {
      description = "Run a command within bubblewrap, enforcing the agent sandbox where nono only grants";
      homepage = "https://github.com/mirkolenz/infra";
      maintainers = with lib.maintainers; [ mirkolenz ];
      platforms = lib.platforms.linux;
    };
  })
