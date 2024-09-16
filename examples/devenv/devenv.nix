# Run with `devenv shell`

{ pkgs, inputs, ... }:

let
  myNushell = inputs.nushellWith.lib.nushellWith {
    inherit pkgs;
    plugins.nix = { nu_plugin_polars = pkgs.nushellPlugins.polars; };
    plugins.source = { nu_plugin_highlight = inputs.highlight; };
    libraries = [ inputs.webserver ];
    bins = with pkgs; [ netcat coreutils ]; # Needed by webserver
  };
in { packages = [ myNushell ]; }
