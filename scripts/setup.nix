{ boostUrl, nixUrl, nixpkgsUrl, writeTextFile }:


writeTextFile rec {
  name = "qemu-riscv64-setup";
  text = ''
    DOWNLOAD_DIR=/opt/qemu-riscv64-setup.d/downloads
    SRC_DIR=/opt/qemu-riscv64-setup.d/src
    INSTALL_PREFIX=/opt/qemu-riscv64-setup.d/local

    [ ! -d $DOWNLOAD_DIR ] && mkdir -p $DOWNLOAD_DIR
    [ ! -d $SRC_DIR ] && mkdir -p $SRC_DIR
    [ ! -d $INSTALL_PREFIX ] && mkdir -p $INSTALL_PREFIX

    echo
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
    [ ! -e nixpkgs-src ] && mkdir nixpkgs-src && tar -xvf $DOWNLOAD_DIR/nixpkgs.tar.gz -C nixpkgs-src --strip-components 1

    pushd nix-src

    ./bootstrap.sh && \
    ./configure --disable-doc-gen --with-sandbox-shell=/bin/sh && \
    make clean && \
    make -j $(nproc) && \
    make install

    [ ! -d /nix ] && mkdir -m 0755 /nix
    chown -R $USER:$USER /nix

    popd

    popd

  '';
  destination = "/etc/${name}.sh";
}
