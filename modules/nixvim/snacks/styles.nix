{
  flake.modules.nixvim.default = {
    plugins.snacks.settings.styles = {
      notification = {
        wo.wrap = true;
      };
      float = {
        position = "float";
        backdrop = 60;
        height = 0.9;
        width = 0.9;
        zindex = 50;
      };
      split = {
        position = "bottom";
        height = 0.3;
        width = 0.5;
      };
    };
  };
}
