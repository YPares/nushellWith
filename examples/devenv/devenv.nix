# Run with `devenv shell`

{ pkgs, inputs, ... }:

let
  nuw = inputs.nushellWith;
  nulibs = nuw.packages.${pkgs.system}.nuLibraries;
  myNushell = nuw.lib.nushellWith {
    inherit pkgs;
    plugins.nix = { nu_plugin_polars = pkgs.nushellPlugins.polars; };
    plugins.source = { nu_plugin_highlight = inputs.highlight; };
    libraries = [ nulibs.webserver-nu ];
  };
in { packages = [ myNushell ]; }
