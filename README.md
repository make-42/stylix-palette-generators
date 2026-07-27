# stylix-palette-generators

Standalone base16 palette generators using [matugen](https://github.com/InioX/matugen)
(Material You) and [tinty](https://github.com/tinted-theming/tinty) — for any
[base16.nix](https://github.com/SenchoPens/base16.nix) consumer (notably [stylix](https://github.com/nix-community/stylix)), extracted from
a year-and-a-half-old, never-merged stylix PR so they work independently of
stylix's internals.

Import it the same way you'd import a set of prebuilt base16 schemes (e.g.
`tinted-theming/schemes` or a catppuccin flake): as a flake input that hands you
scheme data, not as a patch to someone else's module system.

`manual/generator -> merge -> mappingFunction -> base16 consumption`

## Usage

### As a plain base16 scheme (works with any base16.nix consumer, including stylix)

The generators need `pkgs` (to run matugen/tinty as derivations), so `mkScheme`
and `generators` are exposed per-system as flake outputs, plus a `pkgs ->`
variant you can call with your own `pkgs` if you'd rather not index by system
yourself.

```nix
{
  inputs.stylix-palette-generators.url = "github:make-42/stylix-palette-generators";
  outputs = { self, nixpkgs, stylix-palette-generators, ... }:
  let
    system = "x86_64-linux";
    spg = stylix-palette-generators.lib.${system};
  in {
    # ...
    stylix.base16Scheme = spg.mkScheme {
      image = ./wallpaper.png;
      polarity = "dark"; # or "light"
      /*
        generators.base16 = spg.generators.base16.matugen {
        contrast = 0.0;
        lightnessDark = -0.02;
        lightnessLight = 0.0;
        scheme = "fruit-salad";
      };
      */
      /*
        generators.base24 = spg.generators.base24.tinty;
      */
      /*manual = {
        base16 = { base00 = "..."; ... }; # or null
        base24 = { ... };                 # or null
        semantic = { ... };                # or null
      };*/

      generators.semantic = spg.generators.semantic.matugen {
        contrast = 0.0;
        lightnessDark = -0.02;
        lightnessLight = 0.0;
        scheme = "fruit-salad"; #"tonal-spot";  # scheme-fruit-salad: pastel goodness
        # scheme-rainbow: monochrome background, colorful accents,
        # scheme-content: similar to scheme-rainbow
        # scheme-expressive: colors, lots of them.
        # scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot
      };
      mappingFunction = nixpkgs.lib.flip nixpkgs.lib.pipe [
        spg.mappings.semantic2base16
        spg.mappings.base162base24
      ];
    };
  };
}
```

If you already have a `pkgs` in scope (e.g. inside a NixOS/Home Manager
module, via `config._module.args.pkgs`) and don't want to hardcode `system`,
use the pkgs-parametrized helpers instead:

```nix
{ pkgs, lib, ... }:
let
  mkScheme = stylix-palette-generators.lib.mkSchemeWith pkgs;
  generators = stylix-palette-generators.lib.generatorsWith pkgs;
  mappings = stylix-palette-generators.lib.mappings;
in {
  stylix.base16Scheme = mkScheme {
    image = ./wallpaper.png;
    generators.semantic = generators.semantic.matugen { scheme = "fruit-salad"; };
    mappingFunction = lib.flip lib.pipe [
      mappings.semantic2base16
      mappings.base162base24
    ];
  };
}
```

## What's in `lib`

Per-system (`lib.${system}.*`):

- `generators.base16.tinty` / `generators.base16.matugen` — polarity+image → base16 JSON derivation
- `generators.base24.tinty` — polarity+image → base24 JSON derivation
- `generators.semantic.matugen` — polarity+image → semantic (Material You role names) JSON derivation
- `mappings.semantic2base16` — maps Material You roles onto base16 slots
- `mappings.base162base24` / `mappings.base242base16` — base16 ↔ base24 conversions
- `mkScheme` — composed helper: image → base16 attrset

Top-level, pkgs-parametrized (`lib.*`):

- `mkSchemeWith pkgs` — same as `lib.${system}.mkScheme`, given your own `pkgs`
- `generatorsWith pkgs` — same as `lib.${system}.generators`, given your own `pkgs`
- `mappings` — system-independent, same as `lib.${system}.mappings`

## `mkScheme` arguments

```nix
mkScheme {
  image = ./wallpaper.png;   # path, required unless a full manual scheme is given
  polarity = "dark";         # "dark" | "light", default "dark"

  generators = {
    base16 = null;           # polarity: image: derivation, or null
    base24 = null;
    semantic = null;
  };

  manual = {
    base16 = null;           # path | YAML string | attrs, or null
    base24 = null;
    semantic = null;
  };

  mappingFunction = lib.id;  # { polarity, palette } -> { polarity, palette }
}
```

Resolution order per format (`base16`/`base24`/`semantic`): if a generator is
set, it runs against `image`+`polarity`; otherwise the corresponding `manual`
value (if any) is normalized to an attribute set. The three resolved formats
are then passed through `mappingFunction`, and the final `base16` result
(which must not be `null`) is returned as an attrset ready for
`stylix.base16Scheme` or any other base16.nix consumer.

## matugen options

`generators.semantic.matugen` (and `generators.base16.matugen`) accept:

```nix
{
  contrast = 0.0;        # -1.0 .. 1.0
  lightnessDark = 0.0;   # <= 1.0
  lightnessLight = 0.0;  # >= -1.0
  scheme = "content";    # content | expressive | fidelity | fruit-salad |
                         # monochrome | neutral | rainbow | tonal-spot | vibrant
  filter = "lanczos3";   # catmull-rom | gaussian | lanczos3 | nearest | triangle
}
```

## Why this exists

The upstream stylix PR adding first-class matugen support has been open for a
year and a half and required continual rebasing to stay usable. This flake
extracts the working parts so they can be consumed directly without depending
on that PR ever landing.
