crane:
{ pkgs, # From `import nixpkgs {...}`
plugins ? { }
, # Which plugins to use. Can contain `nix` and `source` attributes (lists)
libraries ? { }
, # Which nushell libraries to use. Can contain a `source` attribute (a list)
path ? [ ],
# Which nix paths to add to the PATH. Useful if you directly use libraries
# downloaded from raw sources. IMPORTANT: THE PATH WILL BE EMPTY BY DEFAULT!
nushell ? pkgs.nushell, # Which nushell derivation to use
config-nu ? ./default_config_files/config.nu, # Which config.nu file to use
env-nu ?
  ./default_config_files/env.nu, # Which env.nu file to use (NU_LIB_DIRS will be added to it)
env-vars-file ? null # A sh script describing
}:
with pkgs.lib;
let
  craneLib = crane.mkLib pkgs;

  plugins-with-defs = {
    nix = [ ];
    source = [ ];
  } // plugins;

  libs-with-defs = { source = [ ]; } // libraries;

  # Build the plugins in plugins.source
  crane_pkgs =
    map (src: craneLib.buildPackage { inherit src; }) plugins-with-defs.source;

  all_plugins_paths =
    map (src: "${src}/bin") (plugins-with-defs.nix ++ crane_pkgs);

  # Find the executable for each plugin and write it as a nuon (nu object
  # notation) list in a file
  plugin-exes-list = pkgs.runCommand "nu-plugin-exes-list" { } ''
    ${nushell}/bin/nu -n ${./nu_src}/findBins.nu $out ${
      concatStringsSep " " all_plugins_paths
    }
  '';

  env-nu-with-libs = pkgs.writeText "env.nu" ''
    ${builtins.readFile env-nu}

    $env.NU_LIB_DIRS = [${concatStringsSep " " libs-with-defs.source}]
  '';

  wrapper-script = ''
    #!${pkgs.runtimeShell}

    export PATH=${concatStringsSep ":" path}

    ${if env-vars-file != null then "set -a; source ${env-vars-file}; set +a" else ""}

    ${nushell}/bin/nu \
      --plugins "$(<${plugin-exes-list})" \
      --plugin-config dummy \
      --config ${config-nu} \
      --env-config ${env-nu-with-libs} \
      "$@"
  '';

in pkgs.writeTextFile {
  name = "nushellWith-wrapper";
  text = wrapper-script;
  executable = true;
  destination = "/bin/nu";
}
