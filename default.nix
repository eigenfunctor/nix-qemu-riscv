{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  qemu-system-riscv64 = qemu.override {
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

  qemu-riscv64 = writeTextFile rec {
    name = "qemu-riscv64";
    text = builtins.readFile ./scripts/start-vm.py;
    executable = true;
    destination = "/bin/${name}";
  };
in

stdenv.mkDerivation {
  name = "qemu-riscv";

  buildInputs = [python qemu-system-riscv64 qemu-riscv64];

  shellHook = ''
    export QEMU_IMAGE_ROOT=${builtins.toPath(./images)}
  '';
}
