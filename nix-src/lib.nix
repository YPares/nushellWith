flake-inputs: rec {
  nushellWith = import ./nushell-with.nix flake-inputs;

  # Runs nushell with the given args and uses whatever is written in $env.out as the
  # derivation output
  runNuScript =
    pkgs: name: scriptPath: args:
    pkgs.runCommand name { } ''
      ${pkgs.nushell}/bin/nu -n ${scriptPath} ${pkgs.lib.escapeShellArgs args}
    '';

  # Patch a nushell library so it refers to a specific PATH and can use its dependencies
  makeNuLibrary =
    {
      # Nixpkgs imported:
      pkgs,
      # Name of the library:
      name,
      # Folder containing the library:
      src,
      # Nu libraries this lib depends on:
      dependencies ? [ ],
      # Binary dependencies (list of folders to add to the PATH):
      path ? [ ],
    }:
    runNuScript pkgs name ../nu-src/patch-deps.nu [
      src
      (builtins.toJSON { inherit dependencies path; })
    ];

  # Extract the build env of a derivation as a file
  extractBuildEnv =
    {
      pkgs, # Nixpkgs imported
      drv, # The derivation to override
      preBuildHook ? "", # Bash code to set extra env vars, e.g. by sourcing a file
      selected ? [ ".*" ], # Which env vars to keep (regexes)
      rejected ? [ ], # After selection, which env vars to remove (regexes)
      format ? "nuon", # A file extension. Which format to use for the env file
    }:
    let
      toNuonList = list: "\"[${pkgs.lib.strings.escapeShellArgs list}]\"";
    in
    drv.overrideAttrs {
      name = "${drv.name}-env.${format}";
      buildCommand = ''
        ${preBuildHook}
        ${pkgs.nushell}/bin/nu -n ${../nu-src/extract-env.nu} \
          -s ${toNuonList selected} -r ${toNuonList rejected} -o $out
      '';
    };

  # Make a nushell module that, when imported with 'use' or 'overlay use',
  # will add to the current env the contents of some env files (which can be
  # any format usable by nushell 'open' command)
  makeNuModuleExporting =
    {
      pkgs, # Nixpkgs imported
      env-files, # The json/toml/yaml/nuon env files that the produced module should export
      merge-strategy ? "prepend", # How list-like env vars (notably PATH) should be dealt with
    }:
    pkgs.writeText "env.nu" ''
      use ${../nu-src/extract-env.nu} merge-into-env

      export-env {
        merge-into-env --strategy ${merge-strategy} [${pkgs.lib.strings.concatStringsSep " " env-files}]
      }
    '';

  # Set pkgs once for all the above functions
  mkLib =
    pkgs:
    let
      withPkgs = f: args: f ({ inherit pkgs; } // args);
    in
    {
      nushellWith = withPkgs nushellWith;
      runNuScript = runNuScript pkgs;
      makeNuLibrary = withPkgs makeNuLibrary;
      extractBuildEnv = withPkgs extractBuildEnv;
      makeNuModuleExporting = withPkgs makeNuModuleExporting;
    };
}
