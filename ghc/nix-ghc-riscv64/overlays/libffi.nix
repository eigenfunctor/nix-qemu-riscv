self: super: {
  libffi = super.libffi.overrideAttrs(old: {
    patches = (old.patches or []) ++ [../patches/libffi-riscv-error.patch];
  });
}
