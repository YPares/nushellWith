flake-inputs: rec {
  nushellWith = import ./nushell-with.nix flake-inputs;

  # Runs nushell with the given args and uses whatever is written in $env.out as the
  # derivation output
  runNuScript =
    pkgs: name: scriptPath: args:
    pkgs.runCommand name { } ''
      ${pkgs.nushell}/bin/nu -n ${scriptPath} ${
        pkgs.lib.concatStringsSep " " (map (str: "'" + str + "'") args)
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
}
