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

    nushellWith.url = "github:YPares/nushellWith";
    # It's preferable not to set nushellWith.inputs.nixpkgs.follows, because this would
    # quite likely invalidate the garnix cache and trigger a lot of rebuilds on your machine

    # A repo that contains Nix-packaged Nu libraries:
    monurepo.url = "github:YPares/monurepo";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nushellWith,
      monurepo,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nw_pkgs = nushellWith.packages.${system};
        mr_pkgs = monurepo.packages.${system};
        myNushell = nushellWith {
          inherit pkgs;
          plugins.nix = [ nw_pkgs.nu_plugin_file ];
          libraries.source = [
            mr_pkgs.enverlay
            mr_pkgs.prowser
          ];
          env-vars-file = ./env-vars;
        };
      in
      {
        packages.myNushell = myNushell;
        packages.default = pkgs.writeScriptBin "dummy-command" ''
          #!${pkgs.lib.getExe myNushell}

          use enverlay
          use prowser

          print $"RANDOM_ENV_VAR contains: ($env.RANDOM_ENV_VAR)"
          prowser render | print
        '';
      }
    );
}
