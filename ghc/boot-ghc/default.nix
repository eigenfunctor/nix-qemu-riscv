{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  # TODO: use fetchurl when git repo is stable and public
  ghc = import ../nix-ghc-riscv64 {};
in stdenv.mkDerivation {
  pname = "boot-ghc-binary";
  version = (import ../ghc-version.nix).version;

  src = ./.;

  nativeBuildInputs = [ghc];

  phases = "installPhase";
  installPhase = ''
    mkdir $out
    cd $out
    tar -czf $out/ghc.tar.gz -C ${ghc} .
  '';
}
