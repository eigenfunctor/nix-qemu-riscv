{ pkgs ? import <nixpkgs> {} }:

with pkgs.pkgsCross.riscv64;

nix.override {
  boost = boost17x;
  enableStatic = true;
  withAWS = false;
}
