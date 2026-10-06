{
  lib,
  writers,
  python3Packages,
}:
(writers.writePython3Bin "uv-upgrade" {
  libraries = with python3Packages; [
    packaging
    questionary
  ];
  doCheck = false;
} ./script.py).overrideAttrs
  (prev: {
    meta = prev.meta // {
      description = "Interactively bump the pyproject.toml bounds that exclude the latest versions";
      homepage = "https://github.com/mirkolenz/infra";
      maintainers = with lib.maintainers; [ mirkolenz ];
    };
  })
