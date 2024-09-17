# Patch a nushell library so it refers to a specific PATH
{ pkgs, # Nixpkgs imported
name, # Name of the library
src, # Library folder path
path, # Dependencies (list of folders to add to the PATH)
nushell ? pkgs.nushell # The nushell derivation to use to patch
}:
pkgs.runCommand "${name}-patched" { } ''
  mkdir -p $out

  ${nushell}/bin/nu -n ${./nu_src}/patchDeps.nu \
    ${pkgs.lib.concatStringsSep ":" path} \
    ${src} \
    $out
''
