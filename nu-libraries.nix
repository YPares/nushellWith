# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library here, don't forget to add its inputs to the main flake.nix
{ makeNuLibrary, pkgs, ... }@inputs: {

  # https://github.com/Jan9103/webserver.nu"
  webserver-nu = makeNuLibrary {
    inherit pkgs;
    name = "webserver-nu";
    src = inputs.webserver-nu-src;
    path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
  };

}
