{
  description = "homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        cryptsetup-systemd = pkgs.symlinkJoin {
          name = "cryptsetup-systemd";
          paths = [ pkgs.cryptsetup ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/cryptsetup \
              --prefix LD_LIBRARY_PATH : "${pkgs.systemd}/lib/cryptsetup"
          '';
        };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            packages = [
              ansible
              cryptsetup-systemd
              fido2luks
              libfido2
              rpi-imager
              openssl
              sops
              yubikey-manager
            ];

            ANSIBLE_DEPRECATION_WARNINGS = "False";
            CRYPTSETUP_PATH = "${pkgs.systemd}/lib/cryptsetup";
          };
      }
    );
}
