let
  defcfg = ../default-config-files/config.nu;
  defenv = ../default-config-files/env.nu;
in
flake-inputs:
{
  # Obtained from `import nixpkgs {...}`
  pkgs,
  # How to name the produced derivation
  name ? "nushell-wrapper",
  # Which plugins to use. Can contain `nix` and `source` attributes (both lists)
  plugins ? { },
  # Which nushell libraries to use. Can contain a `source` attribute (a list)
  libraries ? { },
  # Which nix paths to add to the PATH. Useful if you directly use libraries
  # downloaded from raw sources
  path ? [ ],
  # Whether to append to the PATH of the parent process
  # (for more hermeticity) or overwrite it
  keep-path ? false,
  # Which nushell derivation to use
  nushell ? pkgs.nushell,
  # Which config.nu file to set at build time
  config-nu ? defcfg,
  # Which env.nu file to set at build time
  env-nu ? defenv,
  # Should we additionally source the default user's config.nu at runtime if it exists?
  source-user-config ? false,
  # A sh script describing env vars to add to the nushell process
  env-vars-file ? null,
}:
with pkgs.lib;
let
  crane-builder = flake-inputs.crane.mkLib pkgs;

  plugins-with-defs = {
    nix = [ ];
    source = [ ];
  }
  // plugins;

  libs-with-defs = {
    source = [ ];
  }
  // libraries;

  # Build the plugins in plugins.source
  crane-pkgs = map (src: crane-builder.buildPackage { inherit src; }) plugins-with-defs.source;

  plugins-env = pkgs.buildEnv {
    name = "${name}-plugins-env";
    paths = plugins-with-defs.nix ++ crane-pkgs;
    # Creating and saving the plugin list along with the env:
    postBuild = ''
      ${nushell}/bin/nu -n --no-std-lib -c \
        "try {ls $out/bin} catch {[]} | where name =~ nu_plugin_ | get name | save $out/plugins.nuon"
    '';
  };

  edited-config-nu = pkgs.writeText "${name}-config.nu" ''
    source ${config-nu}

    ${
      if source-user-config then
        ''
          const def_user_config_file = $nu.default-config-dir | path join config.nu
          source (if ($def_user_config_file | path exists) {$def_user_config_file})
        ''
      else
        ""
    }

    const NU_LIB_DIRS = (
      ${if source-user-config then ''$NU_LIB_DIRS ++'' else ""}
      [${concatStringsSep " " libs-with-defs.source}]
    )
  '';

  wrapper-script = ''
    #!${pkgs.runtimeShell}

    export PATH=${concatStringsSep ":" ((if keep-path then [ "$PATH" ] else [ ]) ++ path)}

    ${if env-vars-file != null then "set -a; source ${env-vars-file}; set +a" else ""}

    exec ${nushell}/bin/nu \
      --plugin-config "${name}-plugins" \
      --plugins "$(<${plugins-env}/plugins.nuon)" \
      --config "${edited-config-nu}" \
      --env-config ${env-nu} \
      "$@"
  '';

  deriv = pkgs.writeTextFile {
    inherit name;
    text = wrapper-script;
    executable = true;
    destination = "/bin/nu";
  };

in
deriv // { inherit plugins-env; }
