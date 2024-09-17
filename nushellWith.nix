crane:
{ pkgs, # From `import nixpkgs {...}`
plugins ? { }
, # Which plugins to use. Can contain `nix` and `source` attributes (both lists)
libraries ? [ ]
, # Which nushell libraries to use. These can be raw folder downloaded
# from github or archives, or they can be the output of nushellWith.lib.makeNuLibrary
path ? [ ],
# Which nix paths to add to the PATH.
# IMPORTANT: THE PATH WILL BE EMPTY BY DEFAULT!
nushell ? pkgs.nushell, # Which nushell derivation to use
config_file ? ./default_config_files/config.nu, # Which config.nu file to use
env_file ?
  ./default_config_files/env.nu # Which env.nu file to use (NU_LIB_DIRS will be added to it)
}:
with pkgs.lib;
let
  craneLib = crane.mkLib pkgs;
  plugins_with_defs = {
    nix = [ ];
    source = [ ];
  } // plugins;

  # Build the plugins in plugins.source
  crane_pkgs =
    map (src: craneLib.buildPackage { inherit src; }) plugins_with_defs.source;

  all_plugins_paths =
    map (src: "${src}/bin") (plugins_with_defs.nix ++ crane_pkgs);

  # Find the executable for each plugin and write it as a nuon (nu object
  # notation) list in a file
  plugin_exes_list = pkgs.runCommand "nu-plugin-exes-list" { } ''
    ${nushell}/bin/nu -n ${./nu_src}/findBins.nu $out ${
      concatStringsSep " " all_plugins_paths
    }
  '';

  env_file_with_libs = pkgs.writeText "env.nu" ''
    ${builtins.readFile env_file}

    $env.NU_LIB_DIRS = [${concatStringsSep " " libraries}]
  '';

  wrapper_script = ''
    #!${pkgs.runtimeShell}

    export PATH=${concatStringsSep ":" path}

    ${nushell}/bin/nu \
      --plugins "$(<${plugin_exes_list})" \
      --plugin-config dummy \
      --config ${config_file} \
      --env-config ${env_file_with_libs} \
      "$@"
  '';

in pkgs.writeTextFile {
  name = "nushellWith-wrapper";
  text = wrapper_script;
  executable = true;
  destination = "/bin/nu";
}
