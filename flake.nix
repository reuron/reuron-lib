{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = {self, nixpkgs, flake-utils, zig}:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [(final: prev: {
          zigpkgs = zig.packages.${prev.system};
        })];
        pkgs = import nixpkgs { inherit overlays system; };
      in {
        defaultPackage = pkgs.mkDerivation {
          src = ./generate_scene;
          name = "generate-scene";
        };
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.zigpkgs.master
          ];
        };

      });
}
