{
  flake.modules.homeManager.default =
    { ... }:
    {
      home.file.".plantuml/init.puml".text = /* plantuml */ ''
        skinparam Monochrome true
        skinparam Shadowing false
        skinparam ComponentStyle uml2

        skinparam DefaultFontName Palatino
        ' skinparam DefaultFontName Fira Mono
        skinparam TitleFontName Fira Sans
        skinparam TitleFontStyle Bold
      '';
    };
}
