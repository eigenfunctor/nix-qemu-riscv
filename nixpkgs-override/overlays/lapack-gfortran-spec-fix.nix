
self: super: {
  gfortran = super.gfortran11;

  lapack-reference = super.lapack-reference.overrideAttrs(old: {
    patches = (old.patches or []) ++ [
      ../patches/lapack-make.inc.patch
      ../patches/liblapack-disable-tests.patch
    ];

    preConfigure = ''
      ${old.preConfigure or ""}
      export EXTRA_FFLAGS="-I${self.gfortran.cc}/lib -L${self.gfortran.cc}/lib -B${self.gfortran.cc}/lib"
    '';

    configurePhase = ''
      runHook preConfigure
      ${old.configurePhase or ""}
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp ./lib* $out/lib
      cp -r CBLAS/include $out/
      cp -r LAPACKE/include $out/
      cp CBLAS/include/cblas_mangling_with_flags.h.in $out/include/cblas_mangling.h
    '';

    doCheck = false;
  });

  openblas = super.openblas.overrideAttrs(old: {
    patches = (old.patches or []) ++ [
      ../patches/openblas-makefile-system.patch
      ../patches/openblas-disable-utest.patch
    ];

    preConfigure = ''
      ${old.preConfigure or ""}
      export EXTRA_FFLAGS="-I${self.gfortran.cc}/lib -L${self.gfortran.cc}/lib -B${self.gfortran.cc}/lib"
      export EXTRA_CFLAGS="-B${self.stdenv.cc.cc}/lib"
      export LDFLAGS="$LDFLAGS -ldl"
    '';

    configurePhase = ''
      runHook preConfigure
      ${old.configurePhase or ""}
    '';
  });
}
