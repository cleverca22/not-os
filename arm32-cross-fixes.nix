{
  nixpkgs.overlays = [
    (self: super: {
      libuv = super.libuv.overrideAttrs (old: {
        doCheck = false;
      });
      elfutils = super.elfutils.overrideAttrs (old: {
        doCheck = false;
        doInstallCheck = false;
      });
      systemd = super.systemd.override { withEfi = false; };
      util-linux = super.util-linux.override { systemdSupport = false; };
      procps = super.procps.override { withSystemd = false; };
      nix = super.nix.override { enableDocumentation = false; };
    })
  ];
}
