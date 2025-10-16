crane:
let
  lib = rec {
    nushellWith =
      { pkgs, ... }@args:
      let
        nushell = import ./nushell-with.nix crane args;
        lib' = lib.mkLib (pkgs // { inherit nushell; });
      in
      nushell
      // {
        inherit (lib') runNuCommand runNuScript writeNuScriptBin;
      };

    # A nushell version of pkgs.runCommand
    #
    # Use a inlined Nu script to build a derivation.
    # This script should write to $env.out
    runNuCommand =
      pkgs: name: bins: command:
      pkgs.runCommand name bins ''
        ${pkgs.nushell}/bin/nu ${
          pkgs.lib.escapeShellArgs [
            "-c"
            command
          ]
        }
      '';

    # Call a Nu script, passing it arguments, to build a derivation.
    # This script should write to $env.out
    runNuScript =
      pkgs: name: bins: scriptPath: args:
      pkgs.runCommand name bins ''
        ${pkgs.nushell}/bin/nu ${scriptPath} ${pkgs.lib.escapeShellArgs args}
      '';

    # Build a derivation that executes the given inlined nushell script
    writeNuScriptBin =
      pkgs: name: contents:
      pkgs.writeScriptBin name ''
        #!${pkgs.lib.getExe pkgs.nushell}

        ${contents}
      '';

    # Build a derivation that executes the given inlined nushell script,
    # and can add runtimeInputs that this script can use
    writeNushellApplication =
      pkgs: args:
      pkgs.writeShellApplication (
        args
        // {
          text = ''
            #!${pkgs.lib.getExe pkgs.nushell}

            ${args.text}
          '';
        }
      );

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
      runNuScript pkgs name { } ../nu-src/patch-deps.nu [
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
        runNuCommand = runNuCommand pkgs;
        runNuScript = runNuScript pkgs;
        writeNuScriptBin = writeNuScriptBin pkgs;
        writeNushellApplication = writeNushellApplication pkgs;
        makeNuLibrary = withPkgs makeNuLibrary;
        extractBuildEnv = withPkgs extractBuildEnv;
        makeNuModuleExporting = withPkgs makeNuModuleExporting;
      };
  };
in
lib
