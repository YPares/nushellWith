crane:
{
  # Obtained from `import nixpkgs {...}`
  # Expected to contain a 'nushell' derivation
  pkgs,
  # How to name the produced derivation
  name ? "nushell-wrapper",
  # Which plugins to use. Can contain `nix` and `source` attributes (both lists)
  plugins ? { },
  # Which nushell libraries to use. Can contain a `source` attribute (a list)
  libraries ? { },
  # Which nix paths to add to the PATH, so your shell can use to nix-provided executables
  path ? [ ],
  # Which Nu experimental options to activate/desactivate
  # Each attr must be the name of a Nu experimental option, associated to a bool
  experimental-options ? { },
  # Whether to append to the PATH of the parent process or overwrite it for more hermeticity
  keep-path ? true,
  # A fixed config.nu file to read at startup
  config-nu ? null,
  # Should we additionally read the user's config at startup, ie:
  #
  # - source the $HOME/.config/nushell/{config,env}.nu files
  # - keep default locations in $NU_LIB_DIRS ($HOME/.config/nushell/scripts and $HOME/.local/share/nushell/completions)
  #
  # If a config-nu has been given AND source-user-config is true, the former will be source BEFORE the latter.
  source-user-config ? true,
  # Which env.nu file to set at build time (deprecated. Use config-nu for everything instead)
  env-nu ? null,
  # A sh script describing env vars to add to the nushell process
  env-vars-file ? null,
}:
with pkgs.lib;
let
  craneLib = crane.mkLib pkgs;

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
  crane-pkgs = map (src: craneLib.buildPackage { inherit src; }) plugins-with-defs.source;

  plugin-env = pkgs.buildEnv {
    name = "${name}-plugin-env";
    paths = plugins-with-defs.nix ++ crane-pkgs;
    # Creating and saving the plugin list along with the env:
    postBuild = ''
      ${pkgs.nushell}/bin/nu -n --no-std-lib -c \
        "try {ls $out/bin} catch {[]} | where name =~ nu_plugin_ | get name | save $out/plugins.nuon"
    '';
  };

  plugin-env-deriv-name = builtins.replaceStrings [ "/nix/store/" ] [ "" ] plugin-env.outPath;

  edited-config-nu = pkgs.writeText "${name}-config.nu" ''
    const NU_LIB_DIRS = (
      ${if source-user-config then ''$NU_LIB_DIRS ++'' else ""}
      [${concatStringsSep " " libs-with-defs.source}]
    )

    ${if config-nu != null then builtins.readFile config-nu else ""}

    ${
      if source-user-config then
        ''
          const def_user_config_file = $nu.default-config-dir | path join config.nu
          source (if ($def_user_config_file | path exists) {$def_user_config_file})
        ''
      else
        ""
    }
  '';

  experimental-options-str = builtins.concatStringsSep "," (
    builtins.attrValues (
      builtins.mapAttrs (
        name: value:
        let
          valueStr = if value then "true" else "false";
        in
        "${name}=${valueStr}"
      ) experimental-options
    )
  );

  # Nushell needs to be able to write the plugin database (--plugin-config)
  # somewhere, even if that dabase is meant to be readonly afterwards
  #
  # For now we store it in /tmp under the same hash than the
  # plugin-env derivation in order to avoid conflicts
  wrapper-script = ''
    #!${pkgs.runtimeShell}

    export PATH=${concatStringsSep ":" ((if keep-path then [ "$PATH" ] else [ ]) ++ path)}

    ${if env-vars-file != null then "set -a; source ${env-vars-file}; set +a" else ""}

    plugin_db_dir="/tmp/${plugin-env-deriv-name}"
    mkdir -p "$plugin_db_dir"

    ${
      if experimental-options != { } then
        "export NU_EXPERIMENTAL_OPTIONS='${experimental-options-str}'"
      else
        ""
    }

    exec ${pkgs.nushell}/bin/nu \
      --plugins "$(<${plugin-env}/plugins.nuon)" \
      --plugin-config "$plugin_db_dir/plugin-db" \
      --config "${edited-config-nu}" \
      ${
        if env-nu != null then
          "--env-config '${builtins.warn "nushellWith: usage of the `env-nu` parameter is deprecated" env-nu}'"
        else if source-user-config then
          ""
        else
          "--env-config /dev/null"
      } \
      "$@"
  '';

  deriv = pkgs.writeTextFile {
    inherit name;
    text = wrapper-script;
    executable = true;
    destination = "/bin/nu";
  };

in
deriv // { inherit plugin-env; }
