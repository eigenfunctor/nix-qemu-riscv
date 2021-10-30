{ pkgs ? import <nixpkgs> {} }:

with pkgs;

{
  patchelf = {
    name = "boot-patchelf";
    pkg = patchelf;
  };
  expat = {
    name = "boot-expat";
    pkg = expat;
  };
  xz = {
    name = "boot-xz";
    pkg = xz;
  };
}
