{
  description = "Make a nushell instance with specific plugins and/or nushell libraries";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  inputs = {
    crane.url = "github:ipetkov/crane";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Nu libraries' sources:
    nu-batteries-src = {
      url = "github:nome/nu-batteries";
      flake = false;
    };
    webserver-nu-src = {
      url = "github:Jan9103/webserver.nu";
      flake = false;
    };

    crates-io-index = {
      url = "github:rust-lang/crates.io-index";
      flake = false;
    };
  };

  outputs =
    {
      self,
      crane,
      nixpkgs,
      ...
    }@flake-inputs:
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
    in
    {
      lib = import ./nix-src/lib.nix flake-inputs;

      # Makes the flake directly usable as a function:
      __functor = (_: self.lib.nushellWith);

      packages = nixpkgs.lib.genAttrs supported-systems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          inputs-for-libs =
            {
              inherit pkgs;
              inherit system;
            }
            // (builtins.removeAttrs flake-inputs [
              "nixpkgs"
              "flake-utils"
            ]);

          std-plugins = with pkgs.nushellPlugins; [
            formats
            gstat
            polars
            query
          ];

          nu-libs-and-plugins = import ./nix-src/nu-libs-and-plugins.nix inputs-for-libs;

          nu-with =
            name: libs: plugins:
            self.lib.nushellWith {
              inherit pkgs name;
              libraries.source = libs;
              plugins.nix = plugins;
              config-nu = builtins.toFile "empty-config.nu" "# Just source the user config";
              keep-path = true;
              source-user-config = true;
            };
        in
        nu-libs-and-plugins
        // (with nu-libs-and-plugins; {
          nushell = nu-with "nushell-raw" [ ] [ ];
          nushellWithStdPlugins = nu-with "nushell-with-std-plugins" [ ] std-plugins;
          nushellWithExtras =
            nu-with "nushell-with-extras"
              [
                nu-batteries
              ]
              (
                std-plugins
                ++ [
                  nu_plugin_file
                  nu_plugin_plotters
                  nu_plugin_vec
                ]
              );
        })
      );
    };
}
