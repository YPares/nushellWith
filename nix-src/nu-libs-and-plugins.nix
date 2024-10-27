# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{ self, pkgs, ... }@inputs:

let

  nu-libraries = let # Shortcut to build a nu library without too much fuss:
    simpleNuLib = name: extraArgs:
      self.lib.makeNuLibrary ({
        inherit pkgs name;
        src = inputs."${name}-src";
      } // extraArgs);
  in {

    nu-batteries = simpleNuLib "nu-batteries" { };
    webserver-nu = simpleNuLib "webserver-nu" {
      path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
    };

  };

  nu-plugins = let
    craneLib = inputs.crane.mkLib pkgs;

    cratesIoJsonIndex = self.lib.runNuScript pkgs "plugins-in-crates.io-index"
      ../nu-src/list-plugins-in-index.nu [ inputs.crates-io-index ];

    cratesIoIndex =
      builtins.fromJSON (builtins.readFile "${cratesIoJsonIndex}/plugins.json");

    pluginsBaseBuildInputs = with pkgs;
      [ pkg-config ] ++ lib.optionals (stdenv.hostPlatform.isDarwin) [
        iconv
        darwin.apple_sdk.frameworks.IOKit
        darwin.apple_sdk.frameworks.Security
      ];

    # Non-rust dependencies for plugins from crates.io
    #
    # Deps are to be added here on a case-by-case fashion
    buildInputsForPluginsFromCratesIo = with pkgs; {
      binaryview = [ xorg.libX11 ];
      cloud = [ openssl ];
      dbus = [ dbus ];
      fetch = [ openssl ];
      from_dhall = [ openssl ];
      gstat = [ openssl ];
      plotters = [ fontconfig ];
      polars = [ openssl ];
      post = [ openssl ];
      prometheus = [ openssl ];
      query = [ openssl ];
      s3 = [ openssl ];
    };

    buildPluginFromCratesIo = { name, ... }@nameVerCksum:
      let
        src = craneLib.downloadCargoPackage (nameVerCksum // {
          source = "registry+https://github.com/rust-lang/crates.io-index";
        });
        shortName = builtins.replaceStrings ["nu_plugin_"] [""] name;
        buildInputs = pluginsBaseBuildInputs
          ++ (buildInputsForPluginsFromCratesIo.${shortName} or [ ]);
        cargoArtifacts = craneLib.buildDepsOnly { inherit src buildInputs; };
      in craneLib.buildPackage {
        inherit src buildInputs cargoArtifacts;
        doCheck = false;
      };

  in ( # All the plugins from crates.io:
    # (Each attr is of the form "nu_plugin_<name>")
    builtins.mapAttrs (_: buildPluginFromCratesIo) cratesIoIndex) // {
      # Nu plugins from sources other than crates.io:

      nu_plugin_httpserve = let
        src = craneLib.cleanCargoSource inputs.nu_plugin_httpserve-src;
        buildInputs = pluginsBaseBuildInputs;
        cargoArtifacts = craneLib.buildDepsOnly { inherit src buildInputs; };
      in craneLib.buildPackage { inherit src buildInputs cargoArtifacts; };

    };

in nu-libraries // nu-plugins
