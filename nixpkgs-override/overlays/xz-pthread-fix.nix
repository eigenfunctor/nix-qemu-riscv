self: super: {
  xz = super.xz.overrideAttrs(old: {
    preConfigure = ''
      ${old.preConfigure or ""}
      export LDFLAGS="$LDFLAGS -lpthread"
    '';
  });
}
