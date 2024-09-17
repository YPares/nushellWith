# Run with `devenv shell`

{ pkgs, inputs, ... }:

let
  nuw = inputs.nushellWith;
  nupkgs = nuw.packages.${pkgs.system};
  myNushell = nuw.lib.nushellWith {
    inherit pkgs;
    plugins.nix = [ pkgs.nushellPlugins.polars ];
    plugins.source = [ inputs.highlight ];
    libraries = [ nupkgs.webserver-nu ];
  };
in { packages = [ myNushell ]; }
