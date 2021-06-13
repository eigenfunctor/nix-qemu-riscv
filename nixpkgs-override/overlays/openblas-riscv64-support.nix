self: super: {
  openblas = super.openblas.overrideAttrs(old:
    let
      mkMakeFlagValue = val:
        if !builtins.isBool val then builtins.toString val
        else if val then "1" else "0";
      mkMakeFlagsFromConfig = super.lib.mapAttrsToList (var: val: "${var}=${mkMakeFlagValue val}");
    in {
      makeFlags = mkMakeFlagsFromConfig {
        # General config copied from https://github.com/NixOS/nixpkgs/blob/65c7bed5d2149a97922246e043377e7b3bc6eda2/pkgs/development/libraries/science/math/openblas/default.nix
        FC = "${super.stdenv.cc.targetPrefix}gfortran";
        CC = "${super.stdenv.cc.targetPrefix}${if super.stdenv.cc.isClang then "clang" else "cc"}";
        PREFIX = placeholder "out";
        NUM_THREADS = 64;
        INTERFACE64 = super.lib.hasPrefix "x86_64" super.stdenv.hostPlatform.system;
        NO_STATIC = !super.stdenv.hostPlatform.isStatic;
        NO_SHARED = super.stdenv.hostPlatform.isStatic;
        CROSS = super.stdenv.hostPlatform != super.stdenv.buildPlatform;
        HOSTCC = "cc";
        # Makefile.system only checks defined status
        # This seems to be a bug in the openblas Makefile:
        # on x86_64 it expects NO_BINARY_MODE=
        # but on aarch64 it expects NO_BINARY_MODE=0
        NO_BINARY_MODE = if super.stdenv.isx86_64
            then toString (super.stdenv.hostPlatform != super.stdenv.buildPlatform)
            else super.stdenv.hostPlatform != super.stdenv.buildPlatform;

        # RISCV64 config
        BINARY = 64;
        TARGET = "RISCV64_GENERIC";
        DYNAMIC_ARCH = false;
        USE_OPENMP = !super.stdenv.hostPlatform.isMusl;
      };
    }
  );
}
