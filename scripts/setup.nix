{ writeTextFile, nixpkgsChannelUrl }:


writeTextFile rec {
  name = "qemu-riscv64-setup";
  text = ''
    #!/usr/bin/env sh
    set -e

    echo
    echo "Setting up nix for riscv...."
    echo

    matches=(/nix/store/*nix-riscv64-unknown-linux-gnu-*[0-9.])
    export NIX_CROSS_OUTPUT_PATH=''${matches[0]}

    if [ -z $NIX_CROSS_OUTPUT_PATH ]; then
        echo "Cannot find cross compiled nix path."
        echo
        exit 1
    fi

    groupadd -rf nixbld
    for n in $(seq 1 10); do
      id -u nixbld$n &>/dev/null || (useradd -c "Nix build user $n" \
        -d /var/empty -g nixbld -G nixbld -M -N -r -s /usr/bin/nologin \
        nixbld$n)
    done

    $NIX_CROSS_OUTPUT_PATH/bin/nix copy --no-check-sigs --from file:///opt/nix-cross-archive $NIX_CROSS_OUTPUT_PATH

    chown -R riscv:riscv /nix

    cp $NIX_CROSS_OUTPUT_PATH/etc/profile.d/nix.sh /etc/profile.d/nix.sh
    echo "export NIX_PATH=$NIX_PATH:nixpkgs=/opt/nixpkgs-override" > /etc/profile.d/nix-override-path.sh
    chown root:root /etc/profile.d/nix.sh

    chmod 755 /opt/bootstrap-tools-archive/on-server/busybox

    su - riscv -c "\
      $NIX_CROSS_OUTPUT_PATH/bin/nix-channel --add ${nixpkgsChannelUrl} nixpkgs-base && \
      $NIX_CROSS_OUTPUT_PATH/bin/nix-channel --update
    "

    [ ! -d /home/riscv/.nix-profile ] && mkdir /home/riscv/.nix-profile
    [ ! -d /home/riscv/.nix-profile/bin ] && ln -s $NIX_CROSS_OUTPUT_PATH/bin /home/riscv/.nix-profile/bin
    chown -R riscv:riscv /home/riscv/.nix-profile

    dnf install -y \
      git \
      htop \
      tar \

    echo
    echo "Setup Successful"
    echo "Login again or run 'source /etc/profile.d/nix-override-path.sh; source /etc/profile.d/nix.sh'"
    echo
  '';
  destination = "/bin/${name}";
  executable = true;
}
