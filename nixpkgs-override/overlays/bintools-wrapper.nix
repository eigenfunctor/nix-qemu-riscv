self: super:

with super;

with lib;

{
  wrapBintoolsWith = (
    { bintools
    , libc ? if stdenv.targetPlatform != stdenv.hostPlatform then libcCross else stdenv.cc.libc
    , propagateDoc ? bintools != null && bintools ? man
    , ...
    } @ extraArgs:
      let
        libc_bin = if libc == null then null else getBin libc;
        libc_dev = if libc == null then null else getDev libc;
        libc_lib = if libc == null then null else getLib libc;
        bintools_bin = if nativeTools then "" else getBin bintools;

        nativeTools = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeTools or false;
        nativeLibc = stdenv.targetPlatform == stdenv.hostPlatform && stdenv.cc.nativeLibc or false;
        nativePrefix = stdenv.cc.nativePrefix or "";

        noLibc = libc == null;

        sharedLibraryLoader = getLib libc;
        targetPrefix = lib.optionalString (targetPlatform != hostPlatform) (targetPlatform.config + "-");
      in (
        super.wrapBintoolsWith({
          inherit nativeTools nativeLibc nativePrefix noLibc bintools libc;
          inherit (darwin) postLinkSignHook signingUtils;
        } // extraArgs)
      )
        .overrideAttrs(old: rec {
          dynamicLinker = "${sharedLibraryLoader}/lib/ld-${sharedLibraryLoader.version}.so";

          postFixup =
            ##
            ## General libc support
            ##
            optionalString (libc != null) (''
              touch "$out/nix-support/libc-ldflags"
              echo "-L${libc_lib}${libc.libdir or "/lib"}" >> $out/nix-support/libc-ldflags

              echo "${libc_lib}" > $out/nix-support/orig-libc
              echo "${libc_dev}" > $out/nix-support/orig-libc-dev
            ''

            ##
            ## Dynamic linker support
            ##
            + optionalString (sharedLibraryLoader != null) ''
              if [[ -z ''${dynamicLinker+x} ]]; then
                echo "Don't know the name of the dynamic linker for platform '${targetPlatform.config}', so guessing instead." >&2
                local dynamicLinker="${sharedLibraryLoader}/lib/ld*.so.?"
              fi
            ''

            # Expand globs to fill array of options
            + ''
              dynamicLinker=($dynamicLinker)

              case ''${#dynamicLinker[@]} in
                0) echo "No dynamic linker found for platform '${targetPlatform.config}'." >&2;;
                1) echo "Using dynamic linker: '$dynamicLinker'" >&2;;
                *) echo "Multiple dynamic linkers found for platform '${targetPlatform.config}'." >&2;;
              esac

              if [ -n "''${dynamicLinker-}" ]; then
                echo $dynamicLinker > $out/nix-support/dynamic-linker

                ${if targetPlatform.isDarwin then ''
                  printf "export LD_DYLD_PATH=%q\n" "$dynamicLinker" >> $out/nix-support/setup-hook
                '' else optionalString (sharedLibraryLoader != null) ''
                  if [ -e ${sharedLibraryLoader}/lib/32/ld-linux.so.2 ]; then
                    echo ${sharedLibraryLoader}/lib/32/ld-linux.so.2 > $out/nix-support/dynamic-linker-m32
                  fi
                  touch $out/nix-support/ld-set-dynamic-linker
                ''}
              fi
            '')

            ##
            ## User env support
            ##

            # Propagate the underling unwrapped bintools so that if you
            # install the wrapper, you get tools like objdump (same for any
            # binaries of libc).
            + optionalString (!nativeTools) ''
              printWords ${bintools_bin} ${if libc == null then "" else libc_bin} > $out/nix-support/propagated-user-env-packages
            ''

            ##
            ## Man page and info support
            ##
            + optionalString propagateDoc (''
              ln -s ${bintools.man} $man
            '' + optionalString (bintools ? info) ''
              ln -s ${bintools.info} $info
            '')

            ##
            ## Hardening support
            ##

            # some linkers on some platforms don't support specific -z flags
            + ''
              export hardening_unsupported_flags=""
              if [[ "$($ldPath/${targetPrefix}ld -z now 2>&1 || true)" =~ un(recognized|known)\ option ]]; then
                hardening_unsupported_flags+=" bindnow"
              fi
              if [[ "$($ldPath/${targetPrefix}ld -z relro 2>&1 || true)" =~ un(recognized|known)\ option ]]; then
                hardening_unsupported_flags+=" relro"
              fi
            ''

            + optionalString hostPlatform.isCygwin ''
              hardening_unsupported_flags+=" pic"
            ''

            + optionalString targetPlatform.isAvr ''
              hardening_unsupported_flags+=" relro bindnow"
            ''

            + optionalString (libc != null && targetPlatform.isAvr) ''
              for isa in avr5 avr3 avr4 avr6 avr25 avr31 avr35 avr51 avrxmega2 avrxmega4 avrxmega5 avrxmega6 avrxmega7 tiny-stack; do
                echo "-L${getLib libc}/avr/lib/$isa" >> $out/nix-support/libc-cflags
              done
            ''

            + optionalString stdenv.targetPlatform.isDarwin ''
              echo "-arch ${targetPlatform.darwinArch}" >> $out/nix-support/libc-ldflags
            ''

            ###
            ### Remove LC_UUID
            ###
            + optionalString (stdenv.targetPlatform.isDarwin && !(bintools.isGNU or false)) ''
              echo "-no_uuid" >> $out/nix-support/libc-ldflags-before
            ''

            + ''
              for flags in "$out/nix-support"/*flags*; do
                substituteInPlace "$flags" --replace $'\n' ' '
              done
              substituteAll ${<nixpkgs-base/pkgs/build-support/bintools-wrapper/add-flags.sh>} $out/nix-support/add-flags.sh
              substituteAll ${<nixpkgs-base/pkgs/build-support/bintools-wrapper/add-hardening.sh>} $out/nix-support/add-hardening.sh
              substituteAll ${<nixpkgs-base/pkgs/build-support/wrapper-common/utils.bash>} $out/nix-support/utils.bash
            '';
        })
  );
}
