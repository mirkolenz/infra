{
  lib,
  writers,
  python3Packages,
}:
(writers.writePython3Bin "bump-ranges" {
  libraries = with python3Packages; [
    packaging
    questionary
    typer
  ];
  doCheck = false;
} ./script.py).overrideAttrs
  (prev: {
    meta = prev.meta // {
      description = "Interactively bump the dependency ranges that exclude the latest versions";
      homepage = "https://github.com/mirkolenz/infra";
      maintainers = with lib.maintainers; [ mirkolenz ];
    };
  })
