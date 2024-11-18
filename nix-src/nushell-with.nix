let
  defcfg = ../default-config-files/config.nu;
  defenv = ../default-config-files/env.nu;
in
flake-inputs:
{
  # Obtained from `import nixpkgs {...}`
  pkgs
, # How to name the produced derivation
  name ? "nushell-wrapper"
, # Which plugins to use. Can contain `nix` and `source` attributes (both lists)
  plugins ? { }
, # Which nushell libraries to use. Can contain a `source` attribute (a list)
  libraries ? { }
, # Which nix paths to add to the PATH. Useful if you directly use libraries
  # downloaded from raw sources
  path ? [ ]
, # Whether to append to the PATH of the parent process
  # (for more hermeticity) or overwrite it
  keep-path ? false
, # Which nushell derivation to use
  nushell ? pkgs.nushell
, # Which config.nu file to set at build time
  config-nu ? defcfg
, # Which env.nu file to set at build time
  env-nu ? defenv
, # Should we additionally source the user's config.nu & env.nu at runtime?
  # If true, then ~/.config/nushell/{config,env}.nu MUST EXIST
  source-user-config ? false
, # A sh script describing env vars to add to the nushell process
  env-vars-file ? null
,
}:
with pkgs.lib;
let
  crane-builder = flake-inputs.crane.mkLib pkgs;

  plugins-with-defs = {
    nix = [ ];
    source = [ ];
  } // plugins;

  libs-with-defs = { source = [ ]; } // libraries;

  # Build the plugins in plugins.source
  crane-pkgs = map (src: crane-builder.buildPackage { inherit src; })
    plugins-with-defs.source;

  plugins-env = pkgs.buildEnv {
    name = "${name}-plugins-env";
    paths = plugins-with-defs.nix ++ crane-pkgs;
    # Creating and saving the plugin list along with the env:
    postBuild = ''
      ${nushell}/bin/nu --plugin-config dummy --config ${defcfg} --env-config ${defenv} -c \
        "ls $out/bin | where name =~ nu_plugin_ | get name | save $out/plugins.nuon"
    '';
  };

  edited-config-nu = pkgs.writeText "${name}-config.nu" ''
    ${builtins.readFile config-nu}

    ${if source-user-config then ''source "~/.config/nushell/config.nu"'' else ""}
  '';

  edited-env-nu = pkgs.writeText "${name}-env.nu" ''
    ${builtins.readFile env-nu}

    ${if source-user-config then ''source "~/.config/nushell/env.nu"'' else ""}

    $env.NU_LIB_DIRS = [${
      concatStringsSep " " ([ "." ] ++ libs-with-defs.source)
    }]
  '';

  wrapper-script = ''
    #!${pkgs.runtimeShell}

    export PATH=${
      concatStringsSep ":" ((if keep-path then [ "$PATH" ] else [ ]) ++ path)
    }

    ${if env-vars-file != null then
      "set -a; source ${env-vars-file}; set +a"
    else
      ""}

    ${nushell}/bin/nu \
      --plugin-config dummy \
      --plugins "$(<${plugins-env}/plugins.nuon)" \
      --config "${edited-config-nu}" \
      --env-config "${edited-env-nu}" \
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
