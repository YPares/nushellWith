# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{ self, pkgs, ... }@inputs:

let

  nu-libraries =
    let # Shortcut to build a nu library without too much fuss:
      simpleNuLib =
        name: extraArgs:
        self.lib.makeNuLibrary (
          {
            inherit pkgs name;
            src = inputs."${name}-src";
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

  nu-plugins =
    let
      craneLib = inputs.crane.mkLib pkgs;

      pluginsBaseBuildInputs =
        with pkgs;
        [ pkg-config ]
        ++ lib.optionals (stdenv.hostPlatform.isDarwin) [
          iconv
          darwin.apple_sdk.frameworks.IOKit
          darwin.apple_sdk.frameworks.Security
        ];

      pluginSysdeps = import ./plugin-sysdeps.nix pkgs;

      nuPluginCrates = craneLib.buildDepsOnly {
        src = ../dummy_plugin;
        pname = "dummy_plugin";
      };

      buildPluginFromCratesIo =
        { name, ... }@nameVerCksum:
        let
          src = craneLib.downloadCargoPackage (
            nameVerCksum
            // {
              source = "registry+https://github.com/rust-lang/crates.io-index";
            }
          );
          shortName = builtins.replaceStrings [ "nu_plugin_" ] [ "" ] name;
          buildInputs = pluginsBaseBuildInputs ++ (pluginSysdeps.${shortName} or [ ]);
          cargoArtifacts = craneLib.mkCargoDerivation {
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
        craneLib.buildPackage {
          inherit src buildInputs cargoArtifacts;
          doCheck = false;
        };

    in
    # All the plugins from crates.io:
    # (Each attr is of the form "nu_plugin_<name>")
    builtins.mapAttrs (_: buildPluginFromCratesIo) (
      builtins.fromJSON (builtins.readFile ../plugin-list.json)
    );

in
nu-libraries // nu-plugins
