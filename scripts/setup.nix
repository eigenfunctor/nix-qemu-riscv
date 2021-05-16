{ boostUrl, nixUrl, nixpkgsUrl, writeTextFile }:


writeTextFile rec {
  name = "qemu-riscv64-setup";
  text = ''
    #!/usr/bin/env sh

    matches=(/nix/store/*nix-riscv64-unknown-linux-gnu*)
    export NIX_CROSS_OUTPUT_PATH=''${matches[0]}

    dnf -y install file which

    chown -R riscv:riscv /nix

    groupadd -r nixbld
    for n in $(seq 1 10); do
      useradd -c "Nix build user $n" \
      -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(which nologin)" \
      nixbld$n;
    done

    cp $NIX_CROSS_OUTPUT_PATH/lib/systemd/system/nix-daemon.service /etc/systemd/system/nix-daemon.service
    cp $NIX_CROSS_OUTPUT_PATH/lib/systemd/system/nix-daemon.socket /etc/systemd/system/nix-daemon.socket
    cp $NIX_CROSS_OUTPUT_PATH/etc/profile.d/nix-daemon.sh /etc/profile.d/nix-daemon.sh
    cp $NIX_CROSS_OUTPUT_PATH/etc/profile.d/nix.sh /etc/profile.d/nix.sh
    echo "export NIX_REMOTE=daemon" > /etc/profile.d/nix-remote.sh

    chown -R root:root /etc/systemd
    chown -R root:root /etc/profile.d
    chmod 644 /etc/systemd/system/nix-daemon.service
    chmod 644 /etc/systemd/system/nix-daemon.socket
    chmod 644 /etc/profile.d/nix-daemon.sh
    chmod 644 /etc/profile.d/nix.sh
    chmod 644 /etc/profile.d/nix-remote.sh

    systemctl nix-daemon enable
    service nix-daemon start

  '';
  destination = "/bin/${name}";
  executable = true;
}
