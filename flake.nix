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
      lib = import ./nix-src/lib.nix crane;

      # Makes the flake directly usable as a function:
      __functor = _: self.lib.nushellWith;

      overlays.default =
        final: prev:
        let
          craneLib = crane.mkLib prev;
        in
        self.lib.mkLib final
        // {
          inherit craneLib;
          nushellWithStdPlugins = final.nushellWith {
            name = "nushell-with-std-plugins";
            plugins.nix = with final.nushellPlugins; [
              formats
              gstat
              polars
              query
            ];
          };
          # nushell packaged in nixpkgs is already built with the MCP feature
          nushellMCP = final.nushell;
        }
        // import ./nix-src/nu-libs-and-plugins.nix {
          inherit flake-inputs;
          pkgs = final;
        };

      packages = nixpkgs.lib.genAttrs supported-systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) nushell nushellWithStdPlugins nushellMCP;
          semcheck = pkgs.craneLib.buildPackage {
            src = pkgs.craneLib.cleanCargoSource ./semcheck;
            strictDeps = true;
            doCheck = false;
          };
          # packages cannot export functions. So we hack around by providing
          # a derivation that can be used like a function:
          nushellWith = pkgs.nushellWithStdPlugins // {
            __functor = _: pkgs.nushellWith;
          };
        }
        // pkgs.nushellLibraries
        // nixpkgs.lib.mapAttrs' (name: value: {
          name = "nu_plugin_" + name;
          inherit value;
        }) pkgs.nushellPlugins
      );

      apps = nixpkgs.lib.genAttrs supported-systems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          semcheck = self.packages.${system}.semcheck;
        in
        {
          update-plugin-list = {
            type = "app";
            program = pkgs.lib.getExe (pkgs.writeShellApplication {
              name = "update-plugin-list";
              runtimeInputs = [ pkgs.nushell semcheck ];
              text = ''
                exec nu ${./nu-src/update-plugin-list.nu} "$@"
              '';
            });
          };
        }
      );

      checks = nixpkgs.lib.genAttrs supported-systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
          nonBrokenPlugins = pkgs.lib.filterAttrs (_: deriv: !deriv.meta.broken) pkgs.nushellPlugins;
        in
        {
          allStdPlugins = pkgs.nushellWithStdPlugins.runNuCommand "check-all-std-plugins" { } ''
            use std/assert
            assert ((plugin list | length) == 4) "4 plugins should be found"
            assert (plugin list | all {$in.status == "running"}) "All plugins should be running"
            "OK" | save $env.out
          '';
        }
        // nixpkgs.lib.mapAttrs (
          # For each plugin, check that it can be added to nushell without errors
          plugin-name: plugin-deriv:
          let
            nu = pkgs.nushellWith {
              name = "nushell-with-${plugin-name}";
              plugins.nix = [ plugin-deriv ];
            };
          in
          nu.runNuCommand "check-${plugin-name}" { } ''
            use std/assert
            assert ((plugin list | length) == 1) "The plugin should be found"
            assert ((plugin list).0.status == "running") "The plugin should be found"
            "OK" | save $env.out
          ''
        ) nonBrokenPlugins
      );
    };
}
