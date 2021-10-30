let
  overlays = [
    (import ./overlays/libffi.nix)
    (import ./overlays/libuv.nix)
    (import ./overlays/ghc-override.nix)
  ];
in

{ pkgs ? import <nixpkgs> { inherit overlays; } }:

with pkgs.pkgsCross.riscv64;

haskellPackages.ghc
