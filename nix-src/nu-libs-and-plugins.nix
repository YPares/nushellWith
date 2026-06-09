# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{
  flake-inputs,
  prev-pkgs,
  final-pkgs, # Overriden pkgs, with nushell & craneLib
}:
let
  nushellLibraries =
    let # Shortcut to build a nu library without too much fuss:
      simpleNuLib =
        name: extraArgs:
        final-pkgs.makeNuLibrary (
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
      pluginsBaseBuildInputs = with final-pkgs; [ pkg-config ];
      nativeBuildInputs =
        with final-pkgs;
        lib.optionals (stdenv.hostPlatform.isDarwin) [
          iconv
        ];

      pluginSpecifics = import ../plugin-specifics.nix;

      buildPluginFromCratesIo =
        shortName:
        { broken, ... }@infoFromToml:
        let
          src = final-pkgs.craneLib.downloadCargoPackage (
            infoFromToml
            // {
              source = "registry+https://github.com/rust-lang/crates.io-index";
            }
          );
          buildInputs = pluginsBaseBuildInputs ++ ((pluginSpecifics.sysdeps final-pkgs).${shortName} or [ ]);
          cargoArtifacts = final-pkgs.craneLib.buildDepsOnly {
            inherit src buildInputs nativeBuildInputs;
            doCheck = false;
          };
        in
        final-pkgs.craneLib.buildPackage {
          inherit
            src
            buildInputs
            nativeBuildInputs
            cargoArtifacts
            ;
          doCheck = false;
        }
        // {
          meta.broken = broken || builtins.elem shortName pluginSpecifics.known-broken;
        };

    in
    with final-pkgs.lib;
    # all plugins from crates.io:
    mapAttrs buildPluginFromCratesIo (fromTOML (readFile ../plugin-list.toml))
    //
      # plugins to be passed-through from nixpkgs:
      listToAttrs (
        map (name: {
          inherit name;
          value = prev-pkgs.nushellPlugins.${name};
        }) pluginSpecifics.passthrough
      );
in
{
  inherit nushellLibraries nushellPlugins;
}
