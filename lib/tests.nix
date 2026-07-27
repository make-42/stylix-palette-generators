{
  pkgs,
  lib,
  spg,
}: let
  # A small, colorful synthetic image so tests don't depend on network access
  # or a user-supplied file. Multiple color bands give matugen/tinty enough
  # variety to extract a real palette from.
  testImage = ../assets/test.jpg;

  # Assert `cond`, throwing `msg` if false. Building the resulting derivation
  # is what actually "runs" the assertion at evaluation time.
  assertMsg = cond: msg:
    if cond
    then true
    else throw msg;

  # Turns a list of boolean assertions plus a Nix value into a derivation
  # that writes that value out as JSON, so `cat result | jq` shows the real
  # computed scheme instead of a placeholder. Listed under `checks` so it's
  # exercised by `nix flake check` / `nix build .#checks...`.
  #
  # Referencing `allOk` inside the derivation's arguments forces it to be
  # evaluated before/while the derivation is instantiated, so a `throw`
  # inside any assertion aborts evaluation (and therefore the build) with a
  # clear error message.
  mkAssertionCheck = name: assertions: value: let
    allOk = builtins.all lib.id assertions;
    json = builtins.toJSON value;
  in
    pkgs.runCommand "check-${name}"
    {
      env.ASSERTIONS_OK =
        if allOk
        then "1"
        else throw "unreachable";
      passAsFile = ["json"];
      inherit json;
    }
    ''
      cp "$jsonPath" $out
    '';

  isHex6 = s: builtins.isString s && builtins.match "[0-9a-fA-F]{6}" s != null;

  base16Keys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];

  base24ExtraKeys = [
    "base10"
    "base11"
    "base12"
    "base13"
    "base14"
    "base15"
    "base16"
    "base17"
  ];

  hasAllBase16Colors = scheme: builtins.all (k: scheme ? ${k} && isHex6 scheme.${k}) base16Keys;

  hasAllBase24Colors = scheme: hasAllBase16Colors scheme && builtins.all (k: scheme ? ${k} && isHex6 scheme.${k}) base24ExtraKeys;
in {
  # 1. semantic.matugen generator, dark polarity, mapped semantic -> base16 -> base24
  semantic-matugen-dark = let
    scheme = spg.mkScheme {
      image = testImage;
      polarity = "dark";
      generators.semantic = spg.generators.semantic.matugen {scheme = "fruit-salad";};
      mappingFunction = lib.flip lib.pipe [
        spg.mappings.semantic2base16
        spg.mappings.base162base24
      ];
    };
  in
    mkAssertionCheck "semantic-matugen-dark" [
      (assertMsg (scheme.author == "Stylix") "author should be set to Stylix")
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present and hex colors")
    ]
    scheme;

  # 2. Same, but light polarity, to exercise the light-mode mapping table.
  semantic-matugen-light = let
    scheme = spg.mkScheme {
      image = testImage;
      polarity = "light";
      generators.semantic = spg.generators.semantic.matugen {scheme = "fruit-salad";};
      mappingFunction = lib.flip lib.pipe [
        spg.mappings.semantic2base16
        spg.mappings.base162base24
      ];
    };
  in
    mkAssertionCheck "semantic-matugen-light" [
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present and hex colors")
    ]
    scheme;

  # 3. matugen options (contrast/lightness/filter/scheme) are respected and validated.
  semantic-matugen-options = let
    scheme = spg.mkScheme {
      image = testImage;
      polarity = "dark";
      generators.semantic = spg.generators.semantic.matugen {
        contrast = 0.5;
        lightnessDark = -0.02;
        lightnessLight = 0.0;
        scheme = "vibrant";
        filter = "nearest";
      };
      mappingFunction = spg.mappings.semantic2base16;
    };
  in
    mkAssertionCheck "semantic-matugen-options" [
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present with custom matugen options")
    ]
    scheme;

  # 4. base16.matugen generator directly (no semantic mapping needed).
  base16-matugen = let
    scheme = spg.mkScheme {
      image = testImage;
      polarity = "dark";
      generators.base16 = spg.generators.base16.matugen {scheme = "content";};
    };
  in
    mkAssertionCheck "base16-matugen" [
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present from base16.matugen")
    ]
    scheme;

  # 5. base16.tinty generator.
  base16-tinty = let
    scheme = spg.mkScheme {
      image = testImage;
      polarity = "dark";
      generators.base16 = spg.generators.base16.tinty;
    };
  in
    mkAssertionCheck "base16-tinty" [
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present from base16.tinty")
    ]
    scheme;

  # 6. base24.tinty generator, mapped down to base16 via base242base16.
  base24-tinty = let
    scheme = spg.mkScheme {
      image = testImage;
      polarity = "dark";
      generators.base24 = spg.generators.base24.tinty;
      mappingFunction = spg.mappings.base242base16;
    };
  in
    mkAssertionCheck "base24-tinty" [
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present after base242base16 mapping")
    ]
    scheme;

  # 7. Manual base16 scheme, no generator, no image required.
  manual-base16 = let
    manualScheme = {
      base00 = "1a1a2e";
      base01 = "16213e";
      base02 = "0f3460";
      base03 = "533483";
      base04 = "e94560";
      base05 = "f5f5f5";
      base06 = "ffffff";
      base07 = "ffffff";
      base08 = "e94560";
      base09 = "e94560";
      base0A = "e94560";
      base0B = "e94560";
      base0C = "e94560";
      base0D = "e94560";
      base0E = "e94560";
      base0F = "e94560";
    };
    scheme = spg.mkScheme {
      polarity = "dark";
      manual.base16 = manualScheme;
    };
  in
    mkAssertionCheck "manual-base16" [
      (assertMsg (hasAllBase16Colors scheme) "all base16 slots should be present from a manual scheme")
      (assertMsg (scheme.base00 == "1a1a2e") "manual base16 values should pass through unchanged")
    ]
    scheme;

  # 8. base162base24 mapping fills in the extra base24 slots from a manual base16 scheme.
  manual-base16-to-base24 = let
    manualScheme = {
      base00 = "000000";
      base01 = "111111";
      base02 = "222222";
      base03 = "333333";
      base04 = "444444";
      base05 = "555555";
      base06 = "666666";
      base07 = "777777";
      base08 = "888888";
      base09 = "999999";
      base0A = "aaaaaa";
      base0B = "bbbbbb";
      base0C = "cccccc";
      base0D = "dddddd";
      base0E = "eeeeee";
      base0F = "ffffff";
    };
    mapped = spg.mappings.base162base24 {
      polarity = "dark";
      palette = {
        base16 = manualScheme;
        base24 = null;
        semantic = null;
      };
    };
    base24 = mapped.palette.base24;
  in
    mkAssertionCheck "manual-base16-to-base24" [
      (assertMsg (hasAllBase24Colors base24) "base162base24 should produce all base16 + base24 slots")
      (assertMsg (base24.base10 == manualScheme.base00) "base10 should mirror base00 per the mapping table")
      (assertMsg (base24.base12 == manualScheme.base08) "base12 should mirror base08 per the mapping table")
    ]
    base24;

  # 9. Missing base16 after mapping should throw a clear error (negative test).
  # We can't assert `throw` inside a derivation build easily, so this check
  # instead verifies the *evaluation* fails when expected, using `builtins.tryEval`.
  missing-base16-throws = let
    result = builtins.tryEval (
      spg.mkScheme {
        polarity = "dark";
        # No generator, no manual.base16, no mappingFunction that derives one.
      }
    );
  in
    mkAssertionCheck "missing-base16-throws" [
      (assertMsg (!result.success) "mkScheme should throw when no base16 palette can be resolved")
    ] {
      expectedToThrow = true;
      threw = !result.success;
    };

  # 10. mkExtraRepresentations exposes base16, base24, and semantic together,
  # without requiring base16 to be non-null and without throwing.
  extra-representations = let
    reps = spg.mkExtraRepresentations {
      image = testImage;
      polarity = "dark";
      generators.semantic = spg.generators.semantic.matugen {scheme = "fruit-salad";};
      mappingFunction = lib.flip lib.pipe [
        spg.mappings.semantic2base16
        spg.mappings.base162base24
      ];
    };
  in
    mkAssertionCheck "extra-representations" [
      (assertMsg (reps.polarity == "dark") "polarity should be passed through unchanged")
      (assertMsg (hasAllBase16Colors reps.base16) "base16 should be fully populated")
      (assertMsg (hasAllBase24Colors reps.base24) "base24 should be fully populated after base162base24 mapping")
      (assertMsg (reps.semantic != null && reps.semantic ? primary) "semantic should retain the raw Material You role data")
    ]
    reps;
}
