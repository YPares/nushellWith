crane:
{ pkgs, # From `import nixpkgs {...}`
plugins ? { }, # Which plugins to use. Can contain `nix` and `source` attributes
libraries ? [ ]
, # Which nushell libraries to use. These can be raw folder downloaded
# from github or archives, or they can be the output of nushellWith.lib.makeNuLibrary
path ? [ ],
# Which nix paths to add to the PATH.
# IMPORTANT: THE PATH WILL BE EMPTY BY DEFAULT!
nushell ? pkgs.nushell, # Which nushell derivation to use
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

  wrapper_script = ''
    #!${pkgs.runtimeShell}

    export PATH=${concatStringsSep ":" path}

    ${nushell}/bin/nu \
      --plugins "[${concatStringsSep " " all_plugins_paths}]" \
      --plugin-config dummy \
      --config ${config_file} \
      --env-config ${env_file} \
      "$@"
  '';

in pkgs.writeTextFile {
  name = "nushellWith-wrapper";
  text = wrapper_script;
  executable = true;
  destination = "/bin/nu";
}