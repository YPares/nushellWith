# - Run the dummy script with `nix run .`
# - Run the nushell env with `nix run .#myNushell`

{
  description = "Example of how to use nushellWith";

  nixConfig = {
    substituters = [ "https://cache.garnix.io" ];
    trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nushellWith = {
      url = "../.."; # Replace by "github:YPares/nushellWith"
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nushellWith,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nupkgs = nushellWith.packages.${system};
        myNushell = nushellWith {
          inherit pkgs;
          plugins.nix = [ nupkgs.nu_plugin_file ];
          libraries.source = [ nupkgs.nu-batteries ];
          env-vars-file = ./env-vars;
        };
      in
      {
        packages.myNushell = myNushell;
        packages.default = pkgs.writeScriptBin "dummy-command" ''
          #!${pkgs.lib.getExe myNushell}

          use nu-batteries

          print $"RANDOM_ENV_VAR contains: ($env.RANDOM_ENV_VAR)"
        '';
      }
    );
}
