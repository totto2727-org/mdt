{
  description = "Standalone native MoonBit mdt CLI";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    moonbit-overlay = {
      url = "github:totto2727/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moon-registry = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      moonbit-overlay,
      moon-registry,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;
      mkPkgs = system:
        import nixpkgs {
          inherit system;
          overlays = [ moonbit-overlay.overlays.default ];
        };
      mkMdt = pkgs:
        pkgs.callPackage ./package.nix {
          moonRegistryIndex = moon-registry;
        };
    in
    {
      devShells = forEachSystem (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.clang
              pkgs.git
              pkgs.moonbit-bin.moonbit.latest
            ];
          };
        }
      );

      packages = forEachSystem (
        system:
        let
          mdt = mkMdt (mkPkgs system);
        in
        {
          inherit mdt;
          default = mdt;
        }
      );

      overlays.default = _final: prev: {
        mdt = self.packages.${prev.stdenv.hostPlatform.system}.mdt;
      };
    };
}
