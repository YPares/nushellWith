pkgs:
# Declare the non-rust libs (from nixpkgs) that each plugin packaged on crates.io needs to build
#
# Deps are to be added here on a case-by-case fashion
with pkgs; {
  audio_hook = [ alsa-lib ];
  binaryview = [ xorg.libX11 ];
  cassandra_query = [
    cassandra-cpp-driver
    cryptodev
    openssl
    libuv
  ];
  cloud = [ openssl ];
  dbus = [ dbus ];
  fetch = [ openssl ];
  from_dhall = [ openssl ];
  gstat = [ openssl ];
  plotters = [ fontconfig ];
  polars = [ openssl ];
  post = [ openssl ];
  prometheus = [ openssl ];
  query = [ openssl ];
  s3 = [ openssl ];
  twitch = [ openssl ];
  ws = [ openssl ];
}
