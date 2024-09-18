# This flake also exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library here, don't forget to add its inputs to the main flake.nix
{
  # https://github.com/Jan9103/webserver.nu"
  webserver-nu = { pkgs, webserver-nu-src, ... }: {
    src = webserver-nu-src;
    path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
  };
}
