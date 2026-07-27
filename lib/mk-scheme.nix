{ pkgs, lib }:

# mkScheme : {
#   image             : path                                   (required unless manual.base16/base24/semantic given a full scheme)
#   polarity          : "dark" | "light"                        (default "dark")
#   generators.base16   : polarity -> image -> derivation | null
#   generators.base24   : polarity -> image -> derivation | null
#   generators.semantic : polarity -> image -> derivation | null
#   manual.base16     : path | lines | attrs | null
#   manual.base24     : path | lines | attrs | null
#   manual.semantic   : path | lines | attrs | null
#   mappingFunction   : { polarity, palette } -> { polarity, palette }  (default lib.id)
# } -> attrs   # a base16 scheme attrset, ready for base16.nix's `mkSchemeAttrs`

{
  image ? null,
  polarity ? "dark",
  generators ? { },
  manual ? { },
  mappingFunction ? lib.id,
}:
let
  gens = {
    base16 = null;
    base24 = null;
    semantic = null;
  } // generators;

  man = {
    base16 = null;
    base24 = null;
    semantic = null;
  } // manual;

  # Converts a scheme (path/YAML/attrs) into normalized attrs.
  resolveScheme =
    scheme:
    if scheme == null then
      null
    else if lib.isAttrs scheme then
      scheme
    else
      lib.importJSON (
        pkgs.runCommand "scheme.json" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
          yq -o=json < ${scheme} > $out
        ''
      );

  resolved = {
    base16 =
      if gens.base16 != null then
        lib.importJSON (gens.base16 polarity image)
      else
        resolveScheme man.base16;
    base24 =
      if gens.base24 != null then
        lib.importJSON (gens.base24 polarity image)
      else
        resolveScheme man.base24;
    semantic =
      if gens.semantic != null then
        lib.importJSON (gens.semantic polarity image)
      else
        resolveScheme man.semantic;
  };

  mapped = mappingFunction {
    inherit polarity;
    palette = resolved;
  };

  base16 =
    lib.throwIf (mapped.palette.base16 == null)
      ''
        stylix-palette-generators: base16 palette is null after mappingFunction.
        You must provide one of:
          - generators.base16
          - manual.base16
          - a mappingFunction that derives base16 (e.g. semantic -> base16).
      ''
      mapped.palette.base16;
in
base16
// {
  author = "Stylix";
  scheme = "Stylix";
  slug = "stylix";
}
