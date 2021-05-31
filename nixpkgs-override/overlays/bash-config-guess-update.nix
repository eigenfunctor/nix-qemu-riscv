self: super: {
  bash = super.bash.overrideAttrs(old: {
    patches = (old.patches or []) ++ [../patches/bash-config-guess-update.patch];
  });
}
