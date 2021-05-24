{
  pkgs ? import <nixpkgs> {},
  nixpkgsChannelUrl ? "https://nixos.org/channels/nixpkgs-unstable"
}:

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
    inherit nixpkgsChannelUrl;
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
    nix-serve
    python
    qemu-riscv64
    qemu-system-riscv64
  ];

  shellHook = ''
    [ -z "$QEMU_IMAGE_ROOT" ] && export QEMU_IMAGE_ROOT=${builtins.toPath(./images)}
    [ -z "$QEMU_SETUP_SCRIPT_PATH" ] && export QEMU_SETUP_SCRIPT_PATH=${qemu-riscv64-setup}/bin/qemu-riscv64-setup
    [ -z "$QEMU_NIXPKGS_OVERRIDE_PATH" ] && export QEMU_NIXPKGS_OVERRIDE_PATH=${builtins.toPath(./nixpkgs-override)}
    [ -z "$QEMU_NIX_CROSS_PATH" ] && export QEMU_NIX_CROSS_PATH=${builtins.toPath(./nix-cross)}
    [ -z "$QEMU_BOOTSTRAP_TOOLS_PATH" ] && export QEMU_BOOTSTRAP_TOOLS_PATH=${builtins.toPath(./bootstrap-tools)}
    [ -z "$QEMU_NIX_CROSS_ARCHIVE" ] && export QEMU_NIX_CROSS_ARCHIVE=${builtins.toPath(./archive/nix-cross-archive)}
    [ -z "$QEMU_BOOTSTRAP_TOOLS_OUTPUT" ] && export QEMU_BOOTSTRAP_TOOLS_OUTPUT=${(import ./bootstrap-tools {}).build.outPath}
  '';
}
