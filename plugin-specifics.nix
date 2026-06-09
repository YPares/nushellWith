{
  sysdeps =
    pkgs:
    # Declare the non-rust libs (from nixpkgs) that each plugin packaged on crates.io needs to build
    #
    # Deps are to be added here on a case-by-case fashion
    with pkgs; {
      audio = [ alsa-lib ];
      audio_hook = [ alsa-lib ];
      bigquery = [ openssl ];
      binaryview = [ libX11 ];
      cassandra_query = [
        cassandra-cpp-driver
        cryptodev
        openssl
        libuv
      ];
      file = [ openssl ];
      cloud = [ openssl ];
      connectorx = [ perl ];
      dbus = [ dbus ];
      fetch = [ openssl ];
      from_dhall = [ openssl ];
      gstat = [ openssl ];
      input_global_listen = [ libX11 ];
      plotters = [ fontconfig ];
      polars = [ openssl ];
      post = [ openssl ];
      prometheus = [ openssl ];
      query = [
        openssl
        curl
      ];
      s3 = [ openssl ];
      twitch = [ openssl ];
      ws = [ openssl ];
    };

  # These plugins will be flagged as broken:
  known-broken = [
    "from_dhall"
    "unzip"
  ];

  # These plugins will be taken directly from nixpkgs:
  passthrough = [
    # On the master branch, we directly track nushell from nixpkgs,
    # and the official plugins are already provided in nixpkgs and in sync with nushell's version,
    # so we need not rebuild and shadow them
    "formats"
    "gstat"
    "polars"
    "query"
  ];
}
