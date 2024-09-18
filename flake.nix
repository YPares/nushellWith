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

  outputs = { self, crane, nixpkgs, flake-utils, ... }@flake-inputs:
    let
      system-agnostic = { lib = import ./lib.nix flake-inputs; };
      system-specific = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          inputs-for-libs = {
            inherit pkgs;
          } // (builtins.removeAttrs flake-inputs [
            "self"
            "crane"
            "nixpkgs"
            "flake-utils"
          ]);
        in rec {
          nu-libraries-deps = builtins.mapAttrs (name: fn: fn inputs-for-libs)
            (import ./nu-libraries-deps.nix);
          packages = builtins.mapAttrs (name: fn:
            self.lib.makeNuLibrary
            ({ inherit name pkgs; } // fn (inputs-for-libs // nu-libraries-deps)))
            (import ./nu-libraries.nix);
        });
    in system-agnostic // system-specific;
}
