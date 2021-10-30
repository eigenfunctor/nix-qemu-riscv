{ stdenv }:

let
  ghc = builtins.fetchurl "file:///nix/store/boot-ghc-binary/ghc.tar.gz";
in

stdenv.mkDerivation {
  pname = "ghc-cross";
  version = (import ./ghc-version.nix).version;

  src = ./.;

  phases = "intallPhase";
  installPhase = ''
    mkdir $out
    cd $out
    tar -xf ${ghc}
  '';
}
