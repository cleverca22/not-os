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
      # Building nix's manual pulls in mdbook (Rust). We don't need the manual,
      # so swap it for an empty stub to keep mdbook out of the build.
      nix = super.nix.override {
        nix-manual = self.runCommand "nix-manual" { outputs = [ "out" "man" ]; } ''
          mkdir -p "$out" "$man"
        '';
      };
      # Drop ubootTools' EFI scripts so they don't pull Rust into the build.
      ubootTools = super.ubootTools.override { pythonScriptsToInstall = { }; };
    })
  ];
}
