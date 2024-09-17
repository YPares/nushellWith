# Run with `devenv shell`

{ pkgs, inputs, ... }:

let
  nuw = inputs.nushellWith;
  nupkgs = nuw.packages.${pkgs.system};
  myNushell = nuw.lib.nushellWith {
    inherit pkgs;
    plugins.nix = { nu_plugin_polars = pkgs.nushellPlugins.polars; };
    plugins.source = { nu_plugin_highlight = inputs.highlight; };
    libraries = [ nupkgs.webserver-nu ];
  };
in { packages = [ myNushell ]; }
