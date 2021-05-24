{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  bootstrap-tools-cross = import <nixpkgs/pkgs/stdenv/linux/make-bootstrap-tools-cross.nix> {};
in

{
  inherit (bootstrap-tools-cross.riscv64) build;

  bootstrapTools =
    let
      extraAttrs = (
        lib.optionalAttrs
        (config.contentAddressedByDefault or false)
        {
          __contentAddressed = true;
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
        }
      );
    in (
      import <nixpkgs/pkgs/stdenv/linux/bootstrap-tools> {
        system = "riscv64-linux";
        inherit (bootstrap-tools-cross.riscv64) bootstrapFiles;
        inherit extraAttrs;
      }
    );
}
