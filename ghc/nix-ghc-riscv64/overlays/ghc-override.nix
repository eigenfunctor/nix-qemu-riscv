self: super:
  let
    ghcVersion = (import ../../ghc-version.nix).key;
    targetCC = super.pkgsBuildTarget.targetPackages.stdenv.cc;
    notGoldFlag = flag: (builtins.match ".*gold.*" flag) == null;
  in {
    haskell = (super.haskell // {
      packages = (super.haskell.packages // {
        ${ghcVersion} = (super.haskell.packages.${ghcVersion}.override {
          ghc =
            let
              ghcLLVM11 = super.buildPackages.haskell.compiler.${ghcVersion}
                .override({
                  buildLlvmPackages = super.buildPackages.llvmPackages_11;
                  llvmPackages = super.llvmPackages_11;
                });
              ghcWithAtomicFix = ghcLLVM11.overrideAttrs(old: {
                patches = [../patches/riscv64-ghc-atomic-fix.patch] ++ (old.patches or []);
                preConfigure = ''
                  ${old.preConfigure}
                  export LD="${targetCC.bintools}/bin/${targetCC.bintools.targetPrefix}ld"
                  export LDFLAGS+=" -latomic"
                '';
                configureFlags = builtins.filter notGoldFlag (old.configureFlags or []);
                postInstall = ''
                  ${old.postInstall or ""}
                  mkdir -p $out/build
                  cp -ra . $out/build
                  mkdir -p $out/build/ghc/stage2/build/tmp
                  cp $out/bin/${super.stdenv.targetPlatform.config}-ghc-${old.version} $out/build/ghc/stage2/build/tmp/ghc-stage2
                '';
              });
            in ghcWithAtomicFix;
        });
      });
    });
  }
