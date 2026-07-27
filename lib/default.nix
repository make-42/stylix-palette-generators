{ pkgs, lib }:
let
  generators = import ./generators.nix { inherit pkgs lib; };
  mappings = import ./mappings.nix { };
  mkScheme = import ./mk-scheme.nix { inherit pkgs lib; };
in
{
  inherit generators mappings mkScheme;
}
