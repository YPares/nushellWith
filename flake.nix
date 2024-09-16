{
  description = "Make a nushell instance with specific plugins";

  inputs = { crane.url = "github:ipetkov/crane"; };

  outputs = { crane, ... }: {
    lib.nushellWith =
      { pkgs, from-nix ? {}, from-source ? {}, nushell ? pkgs.nushell }:
      with pkgs.lib;
      let
        craneLib = crane.mkLib pkgs;

        from_nix_paths =
          map ({ name, value }: "${value}/bin/${name}") (attrsToList from-nix);

        from_source_paths = map ({ name, value }:
          let p = craneLib.buildPackage { src = value; };
          in "${p}/bin/${name}") (attrsToList from-source);

        all_paths = from_nix_paths ++ from_source_paths;

      in pkgs.writeShellScriptBin "nu" ''
        ${nushell}/bin/nu --plugins "[${concatStringsSep " " all_paths}]"
      '';
  };
}
