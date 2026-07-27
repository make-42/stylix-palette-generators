{ pkgs, lib }:
let
  generators = import ./generators.nix { inherit pkgs lib; };
  mappings = import ./mappings.nix { };
  inherit (import ./mk-scheme.nix { inherit pkgs lib; }) mkScheme mkExtraRepresentations;
in
{
  inherit
    generators
    mappings
    mkScheme
    mkExtraRepresentations
    ;
}
