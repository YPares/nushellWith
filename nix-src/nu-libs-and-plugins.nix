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
        pkgs.makeNuLibrary (
          {
            inherit name;
            src = flake-inputs."${name}-src";
          }
          // extraArgs
        );
    in
    {
      nu-batteries = simpleNuLib "nu-batteries" { };
    };

  nushellPlugins =
    let
      pluginsBaseBuildInputs =
        with pkgs;
        [ pkg-config ]
        ;
      nativeBuildInputs =
        with pkgs;
        lib.optionals (stdenv.hostPlatform.isDarwin) [
          iconv
        ];

      pluginSpecifics = import ../plugin-specifics.nix;

      buildPluginFromCratesIo =
        shortName:
        { broken, ... }@infoFromToml:
        let
          src = pkgs.craneLib.downloadCargoPackage (
            infoFromToml
            // {
              source = "registry+https://github.com/rust-lang/crates.io-index";
            }
          );
          buildInputs = pluginsBaseBuildInputs ++ ((pluginSpecifics.sysdeps pkgs).${shortName} or [ ]);
          cargoArtifacts = pkgs.craneLib.buildDepsOnly {
            inherit src buildInputs nativeBuildInputs;
            doCheck = false;
          };
        in
        pkgs.craneLib.buildPackage {
          inherit src buildInputs nativeBuildInputs cargoArtifacts;
          doCheck = false;
        }
        // {
          meta.broken = broken || builtins.elem shortName pluginSpecifics.known-broken;
        };

    in
    # All the plugins from crates.io:
    builtins.mapAttrs (shortName: buildPluginFromCratesIo shortName) (
      fromTOML (builtins.readFile ../plugin-list.toml)
    );

in
{
  inherit nushellLibraries nushellPlugins;
}
