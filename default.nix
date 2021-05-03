{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  qemu-rv = qemu.override {
    hostCpuTargets = ["riscv64-softmmu"];
    alsaSupport = false;
    pulseSupport = false;
    sdlSupport = false;
    gtkSupport = false;
    vncSupport = false;
    smartcardSupport = false;
    spiceSupport = false;
  };

  python = python38;
in

stdenv.mkDerivation {
  name = "qemu-riscv";

  buildInputs = [python qemu-rv];
}
