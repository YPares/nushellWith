flake-inputs:
{ pkgs, # From `import nixpkgs {...}`
plugins ? { }
, # Which plugins to use. Can contain `nix` and `source` attributes (lists)
libraries ? { }
, # Which nushell libraries to use. Can contain a `source` attribute (a list)
path ? [ ],
# Which nix paths to add to the PATH. Useful if you directly use libraries
# downloaded from raw sources. IMPORTANT: THE PATH WILL BE EMPTY BY DEFAULT!
nushell ? pkgs.nushell, # Which nushell derivation to use
config-nu ? ./default-config-files/config.nu, # Which config.nu file to use
env-nu ? ./default-config-files/env.nu
, # Which env.nu file to use (NU_LIB_DIRS will be added to it)
env-vars-file ? null # A sh script describing
}:
with pkgs.lib;
let
  flake-lib = flake-inputs.self.lib;

  crane-builder = flake-inputs.crane.mkLib pkgs;

  plugins-with-defs = {
    nix = [ ];
    source = [ ];
  } // plugins;

  libs-with-defs = { source = [ ]; } // libraries;

  # Build the plugins in plugins.source
  crane-pkgs = map (src: crane-builder.buildPackage { inherit src; })
    plugins-with-defs.source;

  all-plugin-exes =
    map (src: "${src}/bin") (plugins-with-defs.nix ++ crane-pkgs);

  # Find the executable for each plugin and write it as a nuon (nu object
  # notation) list in a file
  plugin-exes-list =
    flake-lib.runNuScript pkgs "nu-plugin-exes" ./nu-src/find-bins.nu all-plugin-exes;

  env-nu-with-libs = pkgs.writeText "env.nu" ''
    ${builtins.readFile env-nu}

    $env.NU_LIB_DIRS = [${concatStringsSep " " libs-with-defs.source}]
  '';

  wrapper-script = ''
    #!${pkgs.runtimeShell}

    export PATH=${concatStringsSep ":" path}

    ${if env-vars-file != null then
      "set -a; source ${env-vars-file}; set +a"
    else
      ""}

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
