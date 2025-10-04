{
  craneLib,
  lib,
  pkg-config,
  python3,
  rustPlatform,
  zlib,
  xorg,
  nghttp2,
  libgit2,
  stdenv,
  zstd,
  nushell-src,
}:
let
  nativeBuildInputs = [
    pkg-config
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux) [ python3 ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ rustPlatform.bindgenHook ];

  buildInputs = [
    zstd
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ zlib ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux) [ xorg.libX11 ]
  ++ lib.optionals (stdenv.hostPlatform.isDarwin) [
    nghttp2
    libgit2
  ];

  craneArgs = {
    inherit nativeBuildInputs buildInputs;
    src = nushell-src;
    pname = "nushell";
    version = "0.107.0";
    doCheck = false;
  };

  cargoArtifacts = craneLib.buildDepsOnly craneArgs;
in
craneLib.buildPackage (craneArgs // { inherit cargoArtifacts; })
