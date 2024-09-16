{
  description =
    "Make a nushell instance with specific plugins and/or nushell libraries";

  inputs = { crane.url = "github:ipetkov/crane"; };

  outputs = { crane, ... }: {
    lib.nushellWith = { pkgs, # From `import nixpkgs {...}`
      plugins ? { }
      , # Which plugins to use. Can contain `nix` and `source` attributes
      libraries ? [ ], # Which nushell libraries to use
      bins ? [ ],
      # Which packages to add to the PATH (notably for nushell libs sysdeps)
      # THE PATH WILL BE EMPTY BY DEFAULT!
      nushell ? pkgs.nushell # Which nushell derivation to use
      }:
      with pkgs.lib;
      let
        craneLib = crane.mkLib pkgs;
        plugins_with_defs = {
          nix = { };
          source = { };
        } // plugins;

        nix_plugins_paths = map ({ name, value }: "${value}/bin/${name}")
          (attrsToList plugins_with_defs.nix);

        source_plugins_paths = map ({ name, value }:
          let p = craneLib.buildPackage { src = value; };
          in "${p}/bin/${name}") (attrsToList plugins_with_defs.source);

        all_plugins_paths = nix_plugins_paths ++ source_plugins_paths;

        config_file = pkgs.writeText "config.nu" ''
          $env.config = {
            plugin_gc: {
              default: {
                enabled: false
              }
            }
          }
        '';

        env_file = pkgs.writeText "env.nu" ''
          $env.NU_LIB_DIRS = [${concatStringsSep " " libraries}]
        '';

      in pkgs.writeShellScriptBin "nu" ''
        PATH=${
          concatStringsSep ":" (map (deriv: "${deriv}/bin") bins)
        } ${nushell}/bin/nu --plugins "[${
          concatStringsSep " " all_plugins_paths
        }]" --plugin-config dummy --config ${config_file} --env-config ${env_file} "$@"
      '';
  };
}
