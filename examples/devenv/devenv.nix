# Run with `devenv shell`

{ pkgs, inputs, ... }:

let
  nupkgs = inputs.nushellWith.packages.${pkgs.system}; 
  myNushell = inputs.nushellWith {
    inherit pkgs;
    plugins.nix = [ pkgs.nushellPlugins.polars ];
    plugins.source = [ inputs.highlight ];
    libraries.source = [ nupkgs.nu-batteries ];
  };
in { packages = [ myNushell ]; }
