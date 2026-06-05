{
  flake.modules.homeManager.default =
    { ... }:
    {
      programs.poetry = {
        enable = false;
        settings = {
          virtualenvs = {
            in-project = true;
            prefer-active-python = true;
            options = {
              no-pip = true;
              no-setuptools = true;
            };
          };
        };
      };
    };
}
