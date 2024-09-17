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

    # Dependencies for Nu libraries which are not present in nixpkgs:
    
  };

  outputs = { self, crane, nixpkgs, flake-utils, ... }@inputs:
    {
      lib.nushellWith = import ./nushellWith.nix crane;
      lib.makeNuLibrary = import ./makeNuLibrary.nix;
    } // (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        inputsForLibs = {
          inherit pkgs;
        } // (builtins.removeAttrs inputs [
          "self"
          "crane"
          "nixpkgs"
          "flake-utils"
        ]);
        nuLibrariesDeps = builtins.mapAttrs (name: fn: fn inputsForLibs)
          (import ./nuLibrariesDeps.nix);
        nuLibraries = builtins.mapAttrs (name: fn:
          self.lib.makeNuLibrary
          ({ inherit name pkgs; } // fn (inputsForLibs // nuLibrariesDeps)))
          (import ./nuLibraries.nix);
      in { packages = nuLibrariesDeps // { inherit nuLibraries; }; }));
}
