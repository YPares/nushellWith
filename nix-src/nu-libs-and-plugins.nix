# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{ makeNuLibrary, pkgs, ... }@inputs:

let
  # Shortcut to build a nu library without too much fuss:
  simpleLib = name: extraArgs:
    makeNuLibrary ({
      inherit pkgs name;
      src = inputs."${name}-src";
    } // extraArgs);

  craneLib = inputs.crane.mkLib pkgs;
  pluginInputs = builtins.mapAttrs (_: p: craneLib.cleanCargoSource p) inputs;

  # Shortcut to build a plugin from a repo that contains a single crate:
  cratePlugin = shortName: extraArgs:
    craneLib.buildPackage
    ({ src = pluginInputs."plugin-${shortName}-src"; } // extraArgs);

  # Shortcut to build a plugin from a repo that contains a workspace (several crates):
  workspacePlugin = shortName: extraArgs:
    craneLib.buildPackage (rec {
      name = "nu_plugin_${shortName}";
      src = pluginInputs."plugin-${shortName}-src";
      cargoExtraArgs = "-p ${name}";
    } // extraArgs);
in {

  # Libraries (nu code)

  nu-batteries = simpleLib "nu-batteries" { };
  webserver-nu = simpleLib "webserver-nu" {
    path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
  };

  # Plugins (rust code)

  # NOTE: At the time of writing, the Cargo.lock of nu_plugin_explore needs to
  # be updated
  plugin-explore = cratePlugin "explore" { };
  plugin-file = cratePlugin "file" { };
  plugin-httpserve = cratePlugin "httpserve" {
    buildInputs = with pkgs;
      lib.optionals (stdenv.hostPlatform.isDarwin) [
        iconv
        darwin.apple_sdk.frameworks.IOKit
      ];
  };
  plugin-plotters = workspacePlugin "plotters" {
    buildInputs = with pkgs; [ pkg-config fontconfig ];
  };
  plugin-vec = cratePlugin "vec" { };

}
