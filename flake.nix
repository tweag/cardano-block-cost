{
  description = "Cardano block costs";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.mithril.url = "github:input-output-hk/mithril";
  inputs.mithril.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, mithril, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.duckdb
            pkgs.julia-bin
            mithril.packages.${system}.mithril
          ];
        };
      }
    );
}
