[![built with garnix](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2FYPares%2FnushellWith%3Fbranch%3Dmaster)](https://garnix.io/repo/YPares/nushellWith)

# nushellWith

Build an isolated [nushell](https://www.nushell.sh/) environment with a specific
set of plugins (from either nixpkgs or built from source) and nu libraries (from
source).

The recommended way to use this flake is via the `nixpkgs` overlay it provides:

```nix
  let pkgs = import nixpkgs {
    system = ...;
    overlays = [ nushellWith.overlays.default ];
  };
  in {
    # Get nushell built from latest stable version on GitHub:
    nu = pkgs.nushell;

    # A pre-made nushell environment that contains the plugins vendored by the Nushell team:
    nuWithStd = pkgs.nushellWithStdPlugins;

    # Create a derivation that packages a Nu library:
    myNuLib = pkgs.makeNuLibrary {
      name = "my-nu-lib";
      src = ./path/to/folder/containing/lib;
      dependencies = [other-nu-lib ...];
      path = ["${pkgs.some-tool}/bin" ...];
    };

    # Create a Nu environment with specific plugins and libs:
    myNushellEnv = pkgs.nushellWith {
      name = "my-nushell-wrapper";
      # Choose ANY plugin from crates.io that works with current nushell version:
      plugins.nix = with pkgs.nushellPlugins; [
        formats polars semver skim ...
      ];
      # ...or directly use a rust crate which will be built by Nix:
      plugins.source = [
        ./some-nu-plugin-crate-without-sysdeps
      ];
      # Use libraries packaged by makeNuLibrary, or just use a local folder that
      # contains standalone nu modules:
      libraries.source = [
        myNuLib
        ./folder/containing/nu/modules/without/deps
        pkgs.nushellLibraries.nu-batteries
      ];
      # For a more isolated env:
      config-nu = ./some/config.nu; # Use a fixed config.nu when nushell starts
      source-user-config = false; # Do not additionally read the user's ~/.config/nushell/config.nu
      keep-path = false; # Do not expose the parent process' PATH 
    };

    # Make an executable out of a Nu script which runs in myNushellEnv:
    someNuApp = myNushellEnv.writeNuScriptBin "foo" ''
      # ...inlined Nu code that can use the above plugins and libraries...
    '';
    # ...or just in vanilla Nushell:
    otherNuApp = pkgs.writeNuScriptBin "foo" ''
      # ...Nu code...
    '';

    # Use Nu commands that need to access that new env to build derivations:
    someDerivation = myNushellEnv.runNuCommand "foo" {} ''
      # ...inlined nushell code that can use the above plugins and libraries
      # and writes to $env.out...
    '';
    otherDerivation = myNushellEnv.runNuScript "bar" {} ./script-that-needs-plugins-and-libs.nu [scriptArg1 scriptArg2 ...];
  }
```

See also the [`examples`](./examples) folder.

## Outputs of this flake

- [`overlays.default`](./flake.nix), to be used as shown above
- [`lib.*`](./nix-src/lib.nix): the underlying implementation of the functions
  provided by the overlay. There are just the same, but with an extra `pkgs`
  argument each time
- [`packages.<system>.*`](./nix-src/nu-libs-and-plugins.nix): the same
  derivations as the `pkgs.nushell`, `pkgs.nushellWithStdPlugins`,
  `pkgs.nushellLibraries.*` and `pkgs.nushellPlugins.*` provided by the overlay,
  but all merged in the same attrset, and with an extra `nu_plugin_` prefix for
  the attributes corresponding to plugins

## About the packaged nushell libraries & plugins

This flake provides as Nix derivations some nushell libraries and plugins, so
you don't have to write nix derivations for them and deal with their own
dependencies. All plugins from crates.io (ie. every crate named `nu_plugin_*`)
are procedurally packaged, but their system dependencies have to be added on a
[case-by-case fashion](./plugin-sysdeps.nix).

The [plugin list](./plugin-list.toml) that is used to generate the plugin
derivations is fetched from crates.io. To update it, run
`nix run .#update-plugin-list` at the root of this repository. Plugins that
require too old a version of the `nu-protocol` crate will be marked as `broken`
and will neither be built nor checked.

PRs to add new entries to the list of
[packaged libraries & plugins](./nix-src/nu-libs-and-plugins.nix) are very much
welcome.

## Limitations & important notes

Only plugins written in Rust can be passed to `plugins.source`, and they will be
built by [`crane`](https://github.com/ipetkov/crane). `plugins.nix` on the other
hand accepts any derivation that builds a proper plugin, ie. that builds a
`$out/bin/nu_plugin_*` executable which implements the
[nu-plugin protocol](https://www.nushell.sh/contributor-book/plugins.html). In
both cases, the plugin executable is automatically discovered by `nushellWith`.
