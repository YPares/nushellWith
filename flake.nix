{
  description =
    "Make a nushell instance with specific plugins and/or nushell libraries";

  inputs = {
    crane.url = "github:ipetkov/crane";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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
    plugin-httpserve-src = {
      url = "github:YPares/nu_plugin_httpserve";
      flake = false;
    };
    plugin-plotters-src = {
      url = "github:cptpiepmatz/nu-jupyter-kernel";
      flake = false;
    };
  };

  outputs = { self, crane, nixpkgs, ... }@flake-inputs:
    let
      # nixpkgs.lib.systems.flakeExposed, minus powerpc64le-linux
      supported-systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "armv6l-linux"
        "armv7l-linux"
        "i686-linux"
        "aarch64-darwin"
        "riscv64-linux"
        "x86_64-freebsd"
      ];
    in {
      lib = import ./nix-src/lib.nix flake-inputs;

      # Makes the flake directly usable as a function:
      __functor = (_: self.lib.nushellWith);

      packages = nixpkgs.lib.genAttrs supported-systems (system:
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
          std-plugins = with pkgs.nushellPlugins; [
            formats
            gstat
            polars
            query
          ];
          nu-libs-and-plugins =
            import ./nix-src/nu-libs-and-plugins.nix inputs-for-libs;
          nu-with = name: libs: plugins:
            self.lib.nushellWith {
              inherit pkgs name;
              libraries.source = libs;
              plugins.nix = std-plugins ++ plugins;
              config-nu = builtins.toFile "empty-config.nu"
                "#just use the default config";
              keep-path = true;
            };
        in nu-libs-and-plugins // (with nu-libs-and-plugins; {
          nushellWithStdPlugins = nu-with "nushell-with-std-plugins" [ ] [ ];
          nushellWithExtras = nu-with "nushell-with-extras" [ nu-batteries ] [
            plugin-file
            plugin-plotters
          ];
        }));
    };
}
