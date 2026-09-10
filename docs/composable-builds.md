# Composable builds — pay only for the features you use

The engine's side-libraries bake large data tables into the shared library. The
geocoder blob alone is ~7 MB, so the **full** `.so` is ~8 MB, while a
**validation-only** build is **~320 KB** (26× smaller). A consumer who only
needs phone-number validation/formatting shouldn't carry the geocoder, carrier,
timezone and short-number metadata they never call.

So the ABI is **composable**: validation is the base, and each side-library is
an additive opt-in you choose at build time.

## The four optional features (each additive on the validation base)

| Feature | Symbols added | Data cost |
|---|---|---|
| `short` | `pn_embed_short_*` (8) | ~small |
| `tz` | `pn_embed_tz_*` (4) | ~small |
| `carrier` | `pn_embed_carrier_*` (2) | ~0.8 MB |
| `geo` | `pn_embed_geo_*` (2) | ~7 MB |

The base always has the full core `PhoneNumberUtil` surface (parse, validate
with reasons, format, number-type, match, AsYouTypeFormatter, matcher, helpers).

## How it works

`ae build --emit=lib` compiles ONE physical source module and does not emit
re-exported imports, so each variant `.so` must contain its own `pn_embed_*`
definitions in one file. Rather than duplicate the base across variants, the ABI
is kept as fragments and *assembled*:

```
core/embed/base.ae.frag       the core PhoneNumberUtil ABI (+ e164_digits_for)
core/embed/short.ae.frag      + ShortNumberInfo
core/embed/tz.ae.frag         + TimeZones
core/embed/carrier.ae.frag    + Carrier
core/embed/geo.ae.frag        + Geocoder
core/gen/assemble_embed.sh    concatenates base + selected fragments -> a variant .ae
```

This is the standard Aether compile-time-variant idiom: you *select which source
gets compiled*, you don't ask the compiler for conditional compilation. Each
variant is a real, independently-shippable artifact with genuinely different
bytes.

## Building a variant

```
# validation only (~320 KB)
core/gen/assemble_embed.sh core/embed_validation.ae
ae build --emit=lib core/embed_validation.ae --extra core/_embed_support.c \
    -o libphonenumber_ae_validation.so

# validation + geocoder
core/gen/assemble_embed.sh core/embed_geo.ae geo
ae build --emit=lib core/embed_geo.ae --extra core/_embed_support.c -o out.so

# any subset, in any order
core/gen/assemble_embed.sh core/embed_mine.ae tz carrier

# everything (this is what core/embed.ae already is)
core/gen/assemble_embed.sh core/embed.ae all
```

Or via aeb:

- `aeb core/.build.ae` — the **full** library (all features), the default.
- `aeb core/validation.build.ae` — the **validation-only** library.
- Add your own `<name>.build.ae` node whose `source(...)` is your assembled
  variant `.ae` for any other subset.

## Discovering features at runtime

`pn_embed_abi_version()` reports the ABI **revision** (a property of the symbol
definitions), not which features are present. A binding tells whether a given
`.so` carries a feature by `dlsym`-ing one of its symbols — a missing symbol
means the feature was not assembled in. (The bundled bindings link the full
library, so they expose everything; a consumer building a slim variant queries
by symbol presence.)

## Note: this is compile-time selection, not a runtime flag

`--gc-sections` (which the linker already applies) cannot strip the geocoder
blob from the full library: `core/embed.ae` imports `core.geocoder`
unconditionally, so the linker sees the blob as live. The only way to leave the
blob out is to not import it — which is exactly what the fragment assembly does.

A future ergonomics improvement could let `aeb core/.build.ae --with=geocoder`
select features behind a flag, but that is sugar over this model: it would still
need the single-file assembly step, because `--emit=lib` won't merge embeds
regardless. The fragments are the substance; a flag would only hide the
selection.
