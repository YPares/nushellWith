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

    nushellWith.url = "../.."; # Replace with "github:YPares/nushellWith";
    # It's preferable not to set nushellWith.inputs.nixpkgs.follows, because this would
    # quite likely invalidate the garnix cache and trigger a lot of rebuilds on your machine
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
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nushellWith.overlays.default ];
        };
        myNushell = pkgs.nushellWith {
          plugins.nix = with pkgs.nushellPlugins; [ semver ];
          libraries.source = [
            ./libs
          ];
          env-vars-file = ./env-vars;
        };
      in
      {
        packages.myNushellEnv = myNushell;
        packages.default = myNushell.writeNuScriptBin "dummy-script" ''
          use foo

          foo say_hello | print
        '';

        checks.default = myNushell.runNuCommand "dummy-check" { } ''
          use foo

          if (foo version | semver match-req $env.FOO_REQUIRED_VERSION) {
            "OK" | save $env.out
          } else {
            error make {msg: "foo doesn't match expected version"}
          }
        '';
      }
    );
}
