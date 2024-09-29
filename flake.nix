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
    plugin-file-src = {
      url = "github:fdncred/nu_plugin_file";
      flake = false;
    };
    plugin-plotters-src = {
      url = "github:cptpiepmatz/nu-jupyter-kernel";
      flake = false;
    };
  };

  outputs = { self, crane, nixpkgs, flake-utils, ... }@flake-inputs:
    let
      system-agnostic = {
        lib = import ./nix-src/lib.nix flake-inputs;
        # Enables to use the flake directly as a function:
        __functor = (_: self.lib.nushellWith);
      };
      system-specific = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          inputs-for-libs = {
            inherit pkgs;
            inherit system;
            inherit (self.lib) makeNuLibrary;
          } // (builtins.removeAttrs flake-inputs [
            "self"
            "nixpkgs"
            "flake-utils"
          ]);
          std-plugins = with pkgs.nushellPlugins; [ formats gstat polars query ];
          nu-libs-and-plugins = import ./nix-src/nu-libs-and-plugins.nix inputs-for-libs;
          mk-nu-with-extras = name: libs: plugins: self.lib.nushellWith {
            inherit pkgs name;
            libraries.source = libs;
            plugins.nix = std-plugins ++ plugins;
            config-nu = builtins.toFile "nushell-wrapper-config.nu" "#just use the default config";
            keep-path = true;
          };
        in {
          packages = nu-libs-and-plugins // (with nu-libs-and-plugins; {
            nushellWithStdPlugins = mk-nu-with-extras "nushell-with-std-plugins" [] [];
            nushellWithExtras = mk-nu-with-extras "nushell-with-extras"
              [ nu-batteries ]
              [ plugin-file plugin-plotters ];
          });
        });
    in system-agnostic // system-specific;
}
