flake-inputs: rec {
  nushellWith = import ./nushell-with.nix flake-inputs;

  # Runs nushell with the given args and uses whatever is written in $env.out as the
  # derivation output
  runNuScript =
    pkgs: name: scriptPath: args:
    pkgs.runCommand name { } ''
      ${pkgs.nushell}/bin/nu -n ${scriptPath} ${
        pkgs.lib.concatStringsSep " " (map (str: "'" + str + "'") args)
        # TODO: use escapeShellArgs
      }
    '';

  # Patch a nushell library so it refers to a specific PATH
  makeNuLibrary =
    {
      pkgs,
      # Nixpkgs imported
      name,
      # Name of the library
      src,
      # Folder containing the library source
      path ? [ ], # Dependencies (list of folders to add to the PATH)
    }:
    runNuScript pkgs "${name}-patched" ../nu-src/patch-deps.nu ([ src ] ++ path);

  # Extract the build env of a derivation as a nuon file
  extractBuildEnvAsNuonFile =
    {
      pkgs, # Nixpkgs imported
      drv, # The derivation to override
      preBuildHook ? "", # Bash code to set extra env vars, e.g. by sourcing a file
      selected ? [ ".*" ], # Which env vars to keep (regexes)
      rejected ? [ ], # After selection, which env vars to remove (regexes)
    }:
    let
      toNuonList = list: "\"[${pkgs.lib.strings.escapeShellArgs list}]\"";
    in
    drv.overrideAttrs {
      buildCommand = ''
        ${preBuildHook}
        ${pkgs.nushell}/bin/nu -n ${../nu-src/extract-env.nu} \
          ${toNuonList selected} ${toNuonList rejected} > $out
      '';
    };

  # Make a nushell module that, when imported with 'use' or 'overlay use',
  # will add to the current env the contents of nuon-serialized env files
  nuModuleFromNuonEnvFiles =
    pkgs: files:
    pkgs.writeText "env.nu" ''
      use ${../nu-src/extract-env.nu} merge-into-env

      export-env {
        merge-into-env [${pkgs.lib.strings.concatStringsSep " " files}]
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
      extractBuildEnvAsNuonFile = withPkgs extractBuildEnvAsNuonFile;
      nuModuleFromNuonEnvFiles = nuModuleFromNuonEnvFiles pkgs;
    };
}
