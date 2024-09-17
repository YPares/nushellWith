# nushellWith

Build an isolated nushell environment with a specific set of plugins (from
either nixpkgs or built from source) and nu libraries (from source).

See the [`examples`](./examples) folder for how to use it. Examples show usage with regular nix
flakes and with [`devenv`](http://devenv.sh).

## Outputs of this flake

- [`lib.nushellWith`](./nushellWith.nix): a function that takes a description of
  a nushell configuration (which libraries and plugins to use) and outputs a
  nushell wrapper
- [`lib.makeNuLibrary`](./makeNuLibrary.nix): a function that takes a nushell
  library as a folder (e.g. obtained from github via one of your flake inputs
  flagged with `flake = false;`) and patches it to add some binary dependencies
  to its path when it is imported. It outputs the resulting patched folder as a
  derivation, ready to be passed to `libraries` in `lib.nushellWith`
- [`packages.<system>`](./nuLibraries.nix): a set of pre-packaged
  nushell libraries (see below)

## Nushell libraries

This flake also packages (as Nix derivations) some nushell libraries published
on Github, so their dependencies are taken care of for you. PRs to add new
libraries to [`this list`](./nuLibraries.nix) are very much welcome. Don't
forget to add the URL of the library to wrap in the `inputs` of the
[`flake.nix`](./flake.nix) file too.

## Limitations

- Only plugins written in Rust can be used
- Using plugins built from source with `devenv` only works with devenv >= 1.1
