{}:

let
  boostrap-tools-cross = import <nixpkgs/pkgs/stdenv/linux/make-bootstrap-tools-cross.nix> {};
in 

{
  inherit (boostrap-tools-cross.riscv64) build bootstrapTools;
}
