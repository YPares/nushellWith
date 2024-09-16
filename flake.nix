{
  description = "Make a nushell instance with specific plugins and/or nushell libraries";

  inputs = { crane.url = "github:ipetkov/crane"; };

  outputs = { crane, ... }: {
    lib.nushellWith =
      { pkgs, plugins ? {}, libraries ? [], nushell ? pkgs.nushell }:
      with pkgs.lib;
      let
        craneLib = crane.mkLib pkgs;
        plugins_with_defs = {nix={}; source={};} // plugins;

        nix_plugins_paths =
          map ({ name, value }: "${value}/bin/${name}") (attrsToList plugins_with_defs.nix);

        source_plugins_paths = map ({ name, value }:
          let p = craneLib.buildPackage { src = value; };
          in "${p}/bin/${name}") (attrsToList plugins_with_defs.source);

        all_plugins = nix_plugins_paths ++ source_plugins_paths;

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
        ${nushell}/bin/nu --plugins "[${concatStringsSep " " all_plugins}]" --plugin-config dummmy --config ${config_file} --env-config ${env_file} "$@"
      '';
  };
}
