{
  github-linguist = { pkgs, github-linguist-src, ... }:
    let
      ruby = pkgs.ruby;
      gems = pkgs.bundlerEnv {
        inherit ruby;
        name = "github-linguist-env";
        gemdir = github-linguist-src;
      };
    in pkgs.stdenv.mkDerivation rec {
      name = "github-linguist";
      src = github-linguist-src;
      buildInputs = [ gems ruby ];
      installPhase = ''
        mkdir -p $out/{bin,share/${name}}
        cp -r * $out/share/${name}
        bin=$out/bin/${name}
        # we are using bundle exec to start in the bundled environment
        cat > $bin <<EOF
        #!/bin/sh -e
        exec ${gems}/bin/bundle exec ${ruby}/bin/ruby $out/share/${name}/${name} "\$@"
        EOF
            chmod +x $bin
      '';
    };
}
