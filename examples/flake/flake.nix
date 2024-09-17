# Run with `nix run .`

{
  description = "Example of how to use nushellWith";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nushellWith.url = "../.."; # Replace by "github:YPares/nushellWith"
    highlight = {
      url = "github:cptpiepmatz/nu-plugin-highlight";
      flake = false;
    };
  };

  outputs = { nixpkgs, flake-utils, nushellWith, highlight, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        nupkgs = nushellWith.packages.${system};
        myNushell = nushellWith.lib.nushellWith {
          inherit pkgs;
          plugins.nix = [ pkgs.nushellPlugins.polars ];
          plugins.source = [ highlight ];
          libraries = [ nupkgs.webserver-nu ];
        };
      in { packages.default = myNushell; });
}
