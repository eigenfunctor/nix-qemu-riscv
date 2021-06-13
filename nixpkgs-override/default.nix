nixpkgsArgs:
  import <nixpkgs-base> (nixpkgsArgs // {
    overlays = [
      (import ./overlays/xz-pthread-fix.nix)
      (import ./overlays/bash-config-guess-update.nix)
      (import ./overlays/libtool-config-guess-update.nix)
      (import ./overlays/openblas-riscv64-support.nix)
      (import ./overlays/boost-17-override.nix)
      (import ./overlays/lapack-gfortran-spec-fix.nix)
    ] ++ (nixpkgsArgs.overlays or []);

    stdenvStages = args:
      import <nixpkgs-base/pkgs/stdenv/linux> (args // {
        bootstrapFiles = {
          busybox = /opt/bootstrap-tools-archive/on-server/busybox;
          bootstrapTools = /opt/bootstrap-tools-archive/on-server/bootstrap-tools.tar.xz;
        };
      });
  })
