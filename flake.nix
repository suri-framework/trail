{
  description = "Minimal composable server framework for Riot.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    atacama = {
      url = "github:suri-framework/atacama";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.riot.follows = "riot";
      inputs.telemetry.follows = "telemetry";
    };

    melange = {
      url = "github:melange-re/melange";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    minttea = {
      url = "github:leostera/minttea";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rio = {
      url = "github:riot-ml/rio";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    riot = {
      url = "github:riot-ml/riot";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.minttea.follows = "minttea";
      inputs.rio.follows = "rio";
      inputs.telemetry.follows = "telemetry";
    };

    serde = {
      url = "github:serde-ml/serde";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.minttea.follows = "minttea";
      inputs.rio.follows = "rio";
    };

    telemetry = {
      url = "github:leostera/telemetry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        let
          inherit (pkgs) ocamlPackages mkShell;
          inherit (ocamlPackages) buildDunePackage;
          version = "0.0.1+dev";
        in
          {
            devShells = {
              default = mkShell {
                buildInputs = with ocamlPackages; [
                  dune_3
                  ocaml
                  utop
                  ocamlformat
                ];
                inputsFrom = [
                  self'.packages.default
                  self'.packages.sidewinder
                ];
                packages = builtins.attrValues {
                  inherit (ocamlPackages) ocaml-lsp ocamlformat-rpc-lib;
                };
              };
            };

            packages = {
              http = buildDunePackage {
                version = "v6.0.0_beta2";
                pname = "http";
                src = builtins.fetchGit {
                  url = "git@github.com:mirage/ocaml-cohttp.git";
                  rev = "5da40ec181f8afb2ba6788d20c4d35bc8736c649";
                  ref = "refs/tags/v6.0.0_beta2";
                };
              };

              default = buildDunePackage {
                inherit version;
                pname = "trail";
                propagatedBuildInputs = with ocamlPackages; [
                  inputs'.atacama.packages.default
                  bitstring
                  self'.packages.http
                  (mdx.override {
                    inherit logs;
                  })
                  ppx_bitstring
                  qcheck
                  magic-mime
                  inputs'.riot.packages.default
                  uuidm
                  inputs'.melange.packages.default
                ];
                src = ./.;
              };

              ## this derivation is non-working and on hold until sidewinder is refactored
              sidewinder = buildDunePackage {
                inherit version;
                pname = "sidewinder";
                propagatedBuildInputs = with ocamlPackages; [
                  (mdx.override {
                    inherit logs;
                  })
                  magic-mime
                  inputs'.riot.packages.default
                  self'.packages.default
                  crunch
                  inputs'.melange.packages.default
                  inputs'.serde.packages.serde_derive
                ];
                src = ./.;
              };
            };
          };
    };
}
