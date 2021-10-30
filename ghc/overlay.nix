self: super:
  let
    ghcVersion = (import ./ghc-version.nix).key;
    targetCC = super.pkgsBuildTarget.targetPackages.stdenv.cc;
    notGoldFlag = flag: (builtins.match ".*gold.*" flag) == null;
  in {
    haskell = (super.haskell // rec {
      compiler = (super.haskell.compiler // {
        ${ghcVersion} = super.callPackage ./compiler.nix {};
      });
      packages = (super.haskell.packages // {
        ${ghcVersion} = (super.haskell.packages.${ghcVersion}.override {
          buildHaskellPackages = self.buildPackages.haskell.packages.${ghcVersion};
          ghc = compiler.${ghcVersion};
          llvmPackages = super.llvmPackages_11;
        });
      });
    });
  }

