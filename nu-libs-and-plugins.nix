# This flake exposes some existing nushell libraries (packaged with their dependencies)
#
# When adding a library/plugin here, don't forget to add its inputs to the main flake.nix
{ makeNuLibrary, pkgs, system, ... }@inputs:

let craneLib = inputs.crane.mkLib pkgs;
    ccs = craneLib.cleanCargoSource;
in {
  # Libraries (nu code)
  nu-batteries = makeNuLibrary { # https://github.com/nome/nu-batteries
    inherit pkgs;
    name = "nu-batteries";
    src = inputs.nu-batteries-src;
  };
  webserver-nu = makeNuLibrary { # https://github.com/Jan9103/webserver.nu"
    inherit pkgs;
    name = "webserver-nu";
    src = inputs.webserver-nu-src;
    path = with pkgs; [ "${netcat}/bin" "${coreutils}/bin" ];
  };

  # Plugins (rust code)
  plugin-explore = craneLib.buildPackage {
    src = ccs inputs.plugin-explore-src;
    # At the time of writing, the Cargo.lock needs to be updated
  };
  plugin-file = craneLib.buildPackage {
    src = ccs inputs.plugin-file-src;
  };
  plugin-plotters = craneLib.buildPackage {
    src = ccs inputs.plugin-plotters-src;
    cargoExtraArgs = "-p nu_plugin_plotters";
    buildInputs = with pkgs; [ pkg-config fontconfig ];
  };
}
