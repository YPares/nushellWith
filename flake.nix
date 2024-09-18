{
  description =
    "Make a nushell instance with specific plugins and/or nushell libraries";

  inputs = {
    crane.url = "github:ipetkov/crane";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Nu libraries sources:
    webserver-nu-src = {
      url = "github:Jan9103/webserver.nu";
      flake = false;
    };

    # Dependencies for Nu libraries outside of nixpkgs-unstable:

  };

  outputs = { self, crane, nixpkgs, flake-utils, ... }@flakeInputs:
    let
      systemAgnostic = { lib = import ./lib.nix flakeInputs; };
      systemSpecific = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          inputsForLibs = {
            inherit pkgs;
          } // (builtins.removeAttrs flakeInputs [
            "self"
            "crane"
            "nixpkgs"
            "flake-utils"
          ]);
        in rec {
          nuLibrariesDeps = builtins.mapAttrs (name: fn: fn inputsForLibs)
            (import ./nuLibrariesDeps.nix);
          packages = builtins.mapAttrs (name: fn:
            self.lib.makeNuLibrary
            ({ inherit name pkgs; } // fn (inputsForLibs // nuLibrariesDeps)))
            (import ./nuLibraries.nix);
        });
    in systemAgnostic // systemSpecific;
}
