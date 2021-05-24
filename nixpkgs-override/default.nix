nixpkgsArgs:
  import <nixpkgs-base> (nixpkgsArgs // {
    stdenvStages = args:
      import <nixpkgs-base/pkgs/stdenv/linux> (args // {
        bootstrapFiles = {
          busybox = /opt/bootstrap-tools-archive/on-server/busybox;
          bootstrapTools = /opt/bootstrap-tools-archive/on-server/bootstrap-tools.tar.xz;
        };
      });
  })
