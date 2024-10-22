# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{ self, pkgs, ... }@inputs:

let
  # Shortcut to build a nu library without too much fuss:
  simpleLib = name: extraArgs:
    self.lib.makeNuLibrary ({
      inherit pkgs name;
      src = inputs."${name}-src";
    } // extraArgs);

  craneLib = inputs.crane.mkLib pkgs;

  cratesIoJsonIndex = self.lib.runNuScript pkgs "plugins-in-crates.io-index"
    ../nu-src/list-plugins-in-index.nu [ inputs.crates-io-index ];

  cratesIoIndex =
    builtins.fromJSON (builtins.readFile "${cratesIoJsonIndex}/plugins.json");

  baseBuildInputs = with pkgs;
    [ pkg-config ] ++ lib.optionals (stdenv.hostPlatform.isDarwin) [
      iconv
      darwin.apple_sdk.frameworks.IOKit
      darwin.apple_sdk.frameworks.Security
    ];

  buildPluginFromCratesIo = { name, ... }@nameVerCksum:
    let
      src = craneLib.downloadCargoPackage (nameVerCksum // {
        source = "registry+https://github.com/rust-lang/crates.io-index";
      });
      buildInputs = baseBuildInputs
        ++ (buildInputsForPluginsFromCratesIo.${name} or [ ]);
      cargoArtifacts = craneLib.buildDepsOnly { inherit src buildInputs; };
    in craneLib.buildPackage {
      inherit src buildInputs cargoArtifacts;
      doCheck = false;
    };

  # Non-rust dependencies for plugins from crates.io
  buildInputsForPluginsFromCratesIo = with pkgs; {
    nu_plugin_plotters = [ fontconfig ];
    nu_plugin_query = [ openssl ];
  };

  # An attrset of all the plugins from crates.io
  # Each attr is of "nu_plugin_<name>"
  pluginsFromCratesIo =
    builtins.mapAttrs (_: buildPluginFromCratesIo) cratesIoIndex;

in pluginsFromCratesIo // {

  # Libraries (nu code) from github

  nu-batteries = simpleLib "nu-batteries" { };
  webserver-nu = simpleLib "webserver-nu" {
    path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
  };

  # Plugins (rust code) from github 

  nu_plugin_httpserve =
    let src = craneLib.cleanCargoSource inputs.nu_plugin_httpserve-src;
        buildInputs = baseBuildInputs;
        cargoArtifacts = craneLib.buildDepsOnly { inherit src buildInputs; };
    in craneLib.buildPackage {
      inherit src buildInputs cargoArtifacts;
    };

}
