self: super: {
  libuv = super.libuv.overrideAttrs(old: {
    doCheck = false;
  });
}
