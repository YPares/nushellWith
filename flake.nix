{
  description =
    "Make a nushell instance with specific plugins and/or nushell libraries";

  inputs = {
    crane.url = "github:ipetkov/crane";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Nu libraries sources:
    nu-batteries-src = {
      url = "github:nome/nu-batteries";
      flake = false;
    };
    webserver-nu-src = {
      url = "github:Jan9103/webserver.nu";
      flake = false;
    };

    # Nu plugins sources:
    plugin-explore-src = {
      url = "github:amtoine/nu_plugin_explore";
      flake = false;
    };
  };

  outputs = { self, crane, nixpkgs, flake-utils, ... }@flake-inputs:
    let
      system-agnostic = { lib = import ./lib.nix flake-inputs; };
      system-specific = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          inputs-for-libs = {
            inherit pkgs;
            inherit (self.lib) makeNuLibrary;
          } // (builtins.removeAttrs flake-inputs [
            "self"
            "nixpkgs"
            "flake-utils"
          ]);
          nu-libs-and-plugins = import ./nu-libs-and-plugins.nix inputs-for-libs;
          nushellWithStdPlugins = self.lib.nushellWith {
            inherit pkgs;
            plugins.nix = with pkgs.nushellPlugins; [
              polars
              query
              formats
              gstat
            ];
            config-nu = builtins.toFile "nushellWithStdPlugin-config.nu" "#just use the default config";
            keep-path = true;
          };
        in {
          packages = nu-libs-and-plugins // {
            inherit nushellWithStdPlugins;
          };
        });
    in system-agnostic // system-specific;
}
