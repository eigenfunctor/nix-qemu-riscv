{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  python = python38;

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

  qemu-riscv64-setup = callPackage ./scripts/setup.nix {
    boostUrl = "https://boostorg.jfrog.io/artifactory/main/release/1.73.0/source/boost_1_73_0.tar.gz";
    nixUrl = "https://github.com/NixOS/nix/archive/refs/tags/2.3.10.tar.gz";
    nixpkgsUrl = "https://github.com/NixOS/nixpkgs/archive/refs/tags/20.09.tar.gz";
  };

  qemu-riscv64 = writeTextFile rec {
    name = "qemu-riscv64";
    text = builtins.readFile ./scripts/start-vm.py;
    executable = true;
    destination = "/bin/${name}";
  };
in

stdenv.mkDerivation {
  pname = "qemu-riscv";
  version = "0.0.1";

  buildInputs = [
    libguestfs-with-appliance
    python
    qemu-riscv64
    qemu-system-riscv64
  ];

  shellHook = ''
    [ -z "$QEMU_IMAGE_ROOT" ] && export QEMU_IMAGE_ROOT=${builtins.toPath(./images)}
    [ -z "$QEMU_ARCHIVE_ROOT" ] && export QEMU_ARCHIVE_ROOT=${builtins.toPath(./archive)}
    [ -z "$QEMU_SETUP_SCRIPT_PATH" ] && export QEMU_SETUP_SCRIPT_PATH=${qemu-riscv64-setup}/bin/qemu-riscv64-setup
    [ -z "$QEMU_BOOTSTRAP_TOOLS_PATH" ] && export QEMU_BOOTSTRAP_TOOLS_PATH=${builtins.toPath(./bootstrap-tools)}
    [ -z "$QEMU_NIX_DAEMON_SERVICE_PATH" ] && export QEMU_NIX_DAEMON_SERVICE_PATH=${builtins.toPath(./scripts/nix-daemon.service)}
  '';
}
