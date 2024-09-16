# Run with `devenv shell`

{ pkgs, inputs, ... }:

let
  myNushell = inputs.nushellWith.lib.nushellWith {
    inherit pkgs;
    from-nix = { nu_plugin_polars = pkgs.nushellPlugins.polars; };
    from-source = { nu_plugin_highlight = inputs.highlight; };
  };
in {
  packages = [ myNushell ];
}
