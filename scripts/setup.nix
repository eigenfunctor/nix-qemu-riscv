{ boostUrl, nixUrl, nixpkgsUrl, writeTextFile }:


writeTextFile rec {
  name = "qemu-riscv64-setup";
  text = ''
    #!/usr/bin/env bash
    ARCHIVE_DIR=/opt/qemu-riscv64-setup.d/archive
    DOWNLOAD_DIR=/opt/qemu-riscv64-setup.d/downloads
    SRC_DIR=/opt/qemu-riscv64-setup.d/src
    INSTALL_PREFIX=/opt/qemu-riscv64-setup.d/local

    [ ! -d $ARCHIVE_DIR ] && mkdir -p $ARCHIVE_DIR
    [ ! -d $DOWNLOAD_DIR ] && mkdir -p $DOWNLOAD_DIR
    [ ! -d $SRC_DIR ] && mkdir -p $SRC_DIR
    [ ! -d $INSTALL_PREFIX ] && mkdir -p $INSTALL_PREFIX

    echo
    echo "using ARCHIVE_DIR=$ARCHIVE_DIR"
    echo "using DOWNLOAD_DIR=$DOWNLOAD_DIR"
    echo "using SRC_DIR=$SRC_DIR"
    echo "using INSTALL_PREFIX=$INSTALL_PREFIX"
    echo

    pushd $SRC_DIR

    dnf -y install \
      autoconf \
      autoconf-archive \
      automake \
      bison flex \
      boost boost-devel \
      brotli brotli-devel \
      bzip2 bzip2-devel \
      editline editline-devel \
      gcc \
      gcc-g++ \
      git \
      htop \
      kernel-devel \
      libconfig libconfig-devel \
      libcurl libcurl-devel \
      libseccomp libseccomp-devel \
      make \
      openssl openssl-devel \
      patch \
      sqlite sqlite-devel \
      tar \
      wget \
      which \
      xz xz-devel \

    [ ! -e $DOWNLOAD_DIR/boost.tar.gz ] && wget ${boostUrl} -O $DOWNLOAD_DIR/boost.tar.gz
    [ ! -e $DOWNLOAD_DIR/nix.tar.gz ] && wget ${nixUrl} -O $DOWNLOAD_DIR/nix.tar.gz
    [ ! -e $DOWNLOAD_DIR/nixpkgs.tar.gz ] && wget ${nixpkgsUrl} -O $DOWNLOAD_DIR/nixpkgs.tar.gz

    if [ ! -e $INSTALL_PREFIX/lib/libboost_context.so ]; then
      [ ! -e boost-src ] && mkdir boost-src && tar -xvf $DOWNLOAD_DIR/boost.tar.gz -C boost-src --strip-components 1

      pushd boost-src

      ./bootstrap.sh --prefix=$INSTALL_PREFIX --with-libraries=context && \
      ./b2 install

      popd
    fi

    cp $INSTALL_PREFIX/lib/libboost_context.so* /usr/lib64/

    [ ! -e nix-src ] && mkdir nix-src && tar -xvf $DOWNLOAD_DIR/nix.tar.gz -C nix-src --strip-components 1
    [ ! -e nixpkgs ] && mkdir nixpkgs && tar -xvf $DOWNLOAD_DIR/nixpkgs.tar.gz -C nixpkgs --strip-components 1

    pushd nix-src

    if [[ ! "$@" =~ .*--skip-build.* ]]; then
      ./bootstrap.sh && \
      ./configure --disable-doc-gen --with-sandbox-shell=/bin/sh && \
      make clean && \
      make -j $(nproc) && \
      make install
    fi

    [ ! -d /nix ] && mkdir -m 0755 /nix
    chown -R riscv:riscv /nix

    groupadd -r nixbld
    for n in $(seq 1 10); do
      useradd -c "Nix build user $n" \
      -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(which nologin)" \
      nixbld$n;
    done

    chmod 644 /etc/systemd/system/nix-daemon.service
    systemctl nix-daemon enable
    service nix-daemon start

    echo "export NIX_REMOTE=daemon" > /etc/profile.d/set-nix-remote.sh

    popd

    pushd $SRC_DIR/bootstrap-tools

    su riscv -c "\
      export NIX_REMOTE=daemon; \
      nix copy --from file://$ARCHIVE_DIR/bootstrap-tools && \
      nix build -f ./ bootstrapTools --no-link && \
      nix-env -f ./ -i bootstrapTools \
    "

    popd

    popd
  '';
  destination = "/bin/${name}";
  executable = true;
}
