[![built with garnix](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2FYPares%2FnushellWith%3Fbranch%3Dmaster)](https://garnix.io/repo/YPares/nushellWith)

# nushellWith

Build an isolated [nushell](https://www.nushell.sh/) environment with a
specific set of plugins (from either nixpkgs or built from source) and nu
libraries (from source).

See the [`examples`](./examples) folder for how to use it. Examples show
usage with a regular nix flake.

## Outputs of this flake

- the flake itself (or [`lib.nushellWith`](./nix-src/nushell-with.nix)): a function
  that takes a description of a nushell configuration (which libraries, plugins and
  `config.nu` & `env.nu` files to use) and outputs a nushell wrapper. This nushell
  wrapper derivation also has the following attributes:
  - `plugins-env`: a nix env (from `pkgs.buildEnv`) containing symlinks to all
      the wanted plugins. This can be useful if you want a set of plugins grouped
      together in one place.
- [`lib.makeNuLibrary`](./nix-src/lib.nix): a function that takes a nushell library as a
  folder (e.g. obtained from github via one of your flake inputs flagged with
  `flake = false;`) and patches it to add some binary dependencies to its path
  when it is imported. It outputs the resulting patched folder as a derivation,
  ready to be passed to the `libraries.source` argument of `nushellWith`.
  See my [monurepo](https://github.com/ypares/monurepo) repository as an example of how
  external repositories can packages Nu libraries with it
- [`packages.<system>`](./nix-src/nu-libs-and-plugins.nix): a set of pre-packaged
  nushell libraries and plugins (see below)

## Pre-packaged nushell libraries & plugins

This flake also provides as Nix derivations some nushell libraries and
plugins, so you don't have to write nix derivations for them and deal with
their own dependencies. All plugins from crates.io (ie. every crate named
`nu_plugin_*`) are [packaged](./plugin-list.toml), which means some may
fail to build due to their system dependencies not being explicitly listed
[here](./nix-src/plugin-sysdeps.nix). Besides, plugins are tested to check
that they can be loaded with the latest Nushell version (notably, some may
build successfully but not be usable because they use too old a version of the
`nu-plugin` or `nu-protocol` crates).

See the [garnix build results](https://garnix.io/repo/YPares/nushellWith)
to know which plugins failed to build or load, and [this list from
`awesome-nu`](https://github.com/nushell/awesome-nu/blob/main/plugin_details.md)
to check which plugins are based on an up-to-date version of the nu crates.

PRs to add new entries to the list of [packaged libraries &
plugins](./nix-src/nu-libs-and-plugins.nix) are very much welcome.

## Limitations & important notes

Only plugins written in Rust can be passed to `plugins.source`, and they will
be built by [`crane`](https://github.com/ipetkov/crane). `plugins.nix` on the
other hand accepts any derivation that builds a proper plugin, ie. that builds
a `$out/bin/nu_plugin_*` executable which implements the [nu-plugin
protocol](https://www.nushell.sh/contributor-book/plugins.html). In both
cases, the plugin executable is automatically discovered by `nushellWith`.
