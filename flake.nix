{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  inputs.flake-utils.url = github:poscat0x04/flake-utils;

  outputs = { self, nixpkgs, flake-utils, ... }: with flake-utils;
    eachDefaultSystem (
      system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          hpkgs = pkgs.haskellPackages;
          libversion = hpkgs.callCabal2nix "libversion" ./. { libversion = pkgs.libversion; };
          shellDrv = pkgs.haskell.lib.addBuildTools libversion (with pkgs; [
            cabal-install
            haskell-language-server
          ]);
        in
          {
            devShell = shellDrv.envFunc { withHoogle = false; };
            defaultPackage = libversion;
          }
    );
}
