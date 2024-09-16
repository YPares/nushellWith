# Run with `nix run .`

{
  description = "Example of how to use nushellWith";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nushellWith.url = "github:YPares/nushellWith";
    highlight = {
      url = "github:cptpiepmatz/nu-plugin-highlight";
      flake = false;
    };
  };

  outputs = { nixpkgs, flake-utils, nushellWith, highlight, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        myNushell = nushellWith.lib.nushellWith {
          inherit pkgs;
          from-nix = { nu_plugin_polars = pkgs.nushellPlugins.polars; };
          from-source = { nu_plugin_highlight = highlight; };
        };
      in {
        packages.default = myNushell;
      });
}
