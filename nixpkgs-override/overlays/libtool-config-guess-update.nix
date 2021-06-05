self: super: {
  libtool = super.libtool.overrideAttrs(old: {
    patches = (old.patches or []) ++ [../patches/libtool-config-guess-update.patch];
  });
}
