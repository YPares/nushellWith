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
    lib.optionals (stdenv.hostPlatform.isDarwin) [
      iconv
      darwin.apple_sdk.frameworks.IOKit
      darwin.apple_sdk.frameworks.Security
    ];

  buildPluginFromCratesIo = {name, ...}@nameVerCksum:
    craneLib.buildPackage {
      src = craneLib.downloadCargoPackage (nameVerCksum // {
        source = "registry+https://github.com/rust-lang/crates.io-index";
      });
      buildInputs = baseBuildInputs ++ (buildInputsForPluginsFromCratesIo.${name} or []);
      doCheck = false;
    };

  # Non-rust depencies for plugins from crates.io
  buildInputsForPluginsFromCratesIo = {
    nu_plugin_plotters = with pkgs; [ pkg-config fontconfig ];
  };

  # An attrset of all the plugins from crates.io
  # Each attr is of the form "plugin-<name>" instead of "nu_plugin_<name>"
  pluginsFromCratesIo = builtins.mapAttrs (_: buildPluginFromCratesIo) cratesIoIndex;

in pluginsFromCratesIo // {

  # Libraries (nu code) from github

  nu-batteries = simpleLib "nu-batteries" { };
  webserver-nu = simpleLib "webserver-nu" {
    path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
  };

  # Plugins (rust code) from github 

  plugin-httpserve = craneLib.buildPackage {
    src = craneLib.cleanCargoSource inputs.plugin-httpserve-src;
    buildInputs = baseBuildInputs;
  };

}
