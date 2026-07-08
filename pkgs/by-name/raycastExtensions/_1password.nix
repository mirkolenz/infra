{
  mkRaycastExtension,
  fetchFromGitHub,
}:
mkRaycastExtension {
  name = "1password";
  version = "0-unstable-2026-07-08";

  src = fetchFromGitHub {
    owner = "raycast";
    repo = "extensions";
    rev = "3c255e09dd3538621092451e1fb941b7cceb9623";
    hash = "sha256-NpAJi443OsEQwGKb/Tpkobn6pmjzwwYvTJjgvfMv/D8=";
    sparseCheckout = [ "extensions/1password" ];
  };

  npmDepsHash = "sha256-WsFo+xxZXYzMkN3+1GBTfQMxHhiE8vVXqiCD+eC6AP0=";
}
