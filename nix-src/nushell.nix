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
  # Extra features to enable (in addition to defaults, unless noDefaultFeatures is true)
  features ? [],
  # Whether to disable default features
  noDefaultFeatures ? false,
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

  featureArgs =
    lib.optionalString noDefaultFeatures "--no-default-features"
    + lib.optionalString (features != []) " --features ${lib.concatStringsSep "," features}";

  craneArgs = {
    inherit nativeBuildInputs buildInputs;
    src = nushell-src;
    pname = "nushell";
    version = "0.107.0";
    doCheck = false;
  } // lib.optionalAttrs (featureArgs != "") {
    cargoExtraArgs = featureArgs;
  };

  cargoArtifacts = craneLib.buildDepsOnly craneArgs;
in
craneLib.buildPackage (craneArgs // { inherit cargoArtifacts; })
