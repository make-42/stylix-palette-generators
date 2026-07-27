{
  description = "Standalone base16 palette generators using matugen and tinty, extracted from a stylix PR";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    perSystemOutputs = flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        lib = pkgs.lib;
        libFor = import ./lib {inherit pkgs lib;};
        testChecks = import ./lib/tests.nix {
          inherit pkgs lib;
          spg = libFor;
        };
      in {
        lib = libFor;
        checks = testChecks;

        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.matugen
            pkgs.tinty
            pkgs.jq
            pkgs.yq-go
            pkgs.imagemagick
          ];
        };
      }
    );

    # pkgs-parametrized helpers, usable without indexing by system, for
    # callers who already have their own `pkgs` in scope (e.g. inside a
    # NixOS/Home Manager module) and don't want to hardcode `system`.
    extraLib = {
      mkSchemeWith = pkgs:
        (import ./lib {
          inherit pkgs;
          lib = pkgs.lib;
        }).mkScheme;
      generatorsWith = pkgs:
        (import ./lib {
          inherit pkgs;
          lib = pkgs.lib;
        }).generators;
      mappings = import ./lib/mappings.nix {};
    };
  in
    perSystemOutputs
    // {
      # Merge extraLib into each system's `lib`, instead of overwriting it.
      lib = builtins.mapAttrs (_system: sysLib: sysLib // extraLib) perSystemOutputs.lib;
    };
}
