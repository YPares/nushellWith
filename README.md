# nushellWith

Build a nushell with a specific set of plugins. See the examples folder

## Limitations

Using plugins built from source doesn't work with devenv yet, because when building plugins, cargo wants to regenerate the Cargo.lock generated by `crane` (which is readonly). To be investigated.