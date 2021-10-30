{
  pkgs ? import <nixpkgs> { }
, crossPkgs ? pkgs.pkgsCross.riscv64
, bootPackages ? import ./boot-packages.nix { pkgs = crossPkgs; }
}:

with crossPkgs;

let
  bootPackagesList = pkgs.lib.attrValues bootPackages;

  mkInstallSnippet = p:
    let
      mkInstallSnippetOutput = o: ''
        cp -r ${p.pkg.${o}} ${o}
        chmod -R gua+rw ${o}
        tar -rf ${p.name}.tar ${o}
        rm -rf ${o}
      '';
    in ''
      tar -cf ${p.name}.tar -T /dev/null
    ''
    + (builtins.concatStringsSep "\n"
      (builtins.map mkInstallSnippetOutput p.pkg.outputs));

in stdenv.mkDerivation rec {
  name = "boot-packages";

  src = ./.;

  nativeBuildInputs = (builtins.map (p: p.pkg) bootPackagesList);

  phases = "installPhase";

  installPhase = ''
    mkdir $out
    cd $out
  ''
  + (builtins.concatStringsSep "\n"
    (builtins.map mkInstallSnippet bootPackagesList));
}
