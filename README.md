# nushellWith

Build an isolated [nushell](https://www.nushell.sh/) environment with a specific set of plugins (from
either nixpkgs or built from source) and nu libraries (from source).

See the [`examples`](./examples) folder for how to use it. Examples show usage with regular nix
flakes and with [`devenv`](http://devenv.sh).

## Outputs of this flake

- [`lib.nushellWith`](./nix-src/nushell-with.nix): a function that takes a description
  of a nushell configuration (which libraries and plugins to use) and outputs a
  nushell wrapper
- [`lib.makeNuLibrary`](./nix-src/lib.nix): a function that takes a nushell library as a
  folder (e.g. obtained from github via one of your flake inputs flagged with
  `flake = false;`) and patches it to add some binary dependencies to its path
  when it is imported. It outputs the resulting patched folder as a derivation,
  ready to be passed to the `libraries.source` argument of `nushellWith`
- [`packages.<system>`](./nix-src/nu-libs-and-plugins.nix): a set of pre-packaged
  nushell libraries and plugins (see below)

## Pre-packaged nushell libraries & plugins

This flake also provides as Nix derivations some nushell libraries and plugins
published on Github, so you don't have to write nix derivations for them and
deal with their own dependencies. PRs to add new things to [this
list](./nu-libs-and-plugins.nix) are very much welcome. Don't forget to add the
URL of the library/plugin (and also of its external dependencies if it has any)
to the `inputs` of the main [`flake.nix`](./flake.nix).

The nix attribute names of the provided plugins should be of the form `plugin-*`
to tell plugins and libraries apart.

## Limitations & important notes

- Only plugins written in Rust can be passed to `plugins.source`, and they will
  be built by [`crane`](https://github.com/ipetkov/crane). `plugins.nix` on the
  other hand accepts any derivation that builds a proper plugin, ie. that builds
  one single `$out/bin/nu_plugin_*` executable which implements the [nu-plugin
  protocol](https://www.nushell.sh/contributor-book/plugins.html). In both
  cases, the plugin executable is automatically discovered by `nushellWith`, and
  must be the _only_ executable present in the given derivation.
- Using `plugins.source` with `devenv` only works with `devenv >= v1.1`.
