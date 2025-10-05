# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{
  flake-inputs,
  pkgs, # Overriden pkgs, with nushell & craneLib
}:
let
  nushellLibraries =
    let # Shortcut to build a nu library without too much fuss:
      simpleNuLib =
        name: extraArgs:
        pkgs.nushell.makeNuLibrary (
          {
            inherit name;
            src = flake-inputs."${name}-src";
          }
          // extraArgs
        );
    in
    {
      nu-batteries = simpleNuLib "nu-batteries" { };

      webserver-nu = simpleNuLib "webserver-nu" {
        path = with pkgs; [
          "${netcat}/bin"
          "${coreutils}/bin"
        ];
      };
    };

  nushellPlugins =
    let
      pluginsBaseBuildInputs =
        with pkgs;
        [ pkg-config ]
        ++ lib.optionals (stdenv.hostPlatform.isDarwin) [
          iconv
          darwin.apple_sdk.frameworks.IOKit
          darwin.apple_sdk.frameworks.Security
        ];

      pluginSysdeps = import ../plugin-sysdeps.nix pkgs;

      nuPluginCrates = pkgs.craneLib.buildDepsOnly {
        src = ../dummy_plugin;
        pname = "dummy_plugin";
      };

      knownBroken = import ../known-broken-plugins.nix;

      buildPluginFromCratesIo =
        shortName:
        { name, broken, ... }@infoFromToml:
        let
          src = pkgs.craneLib.downloadCargoPackage (
            infoFromToml
            // {
              source = "registry+https://github.com/rust-lang/crates.io-index";
            }
          );
          buildInputs = pluginsBaseBuildInputs ++ (pluginSysdeps.${shortName} or [ ]);
          cargoArtifacts = pkgs.craneLib.mkCargoDerivation {
            inherit src buildInputs;
            cargoArtifacts = nuPluginCrates;
            buildPhaseCargoCommand = ''
              cargoWithProfile check --locked
              cargoWithProfile build --locked
            '';
            checkPhaseCargoCommand = ''
              cargoWithProfile test --locked
            '';
            doInstallCargoArtifacts = true;
          };
        in
        pkgs.craneLib.buildPackage {
          inherit src buildInputs cargoArtifacts;
          doCheck = false;
        }
        // {
          meta.broken = broken || builtins.elem shortName knownBroken;
        };

    in
    # All the plugins from crates.io:
    builtins.mapAttrs (shortName: buildPluginFromCratesIo shortName) (
      builtins.fromTOML (builtins.readFile ../plugin-list.toml)
    );

in
{
  inherit nushellLibraries nushellPlugins;
}
