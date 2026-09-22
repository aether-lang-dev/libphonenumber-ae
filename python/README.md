# phonenumber_ae — Python

A thin Python binding over the shared, pure-Aether libphonenumber core. All the
phone logic lives in the one core (`core/phonenumber.ae`); this binding is just
ctypes marshalling over `libphonenumber_ae.so`. See the
[repo README](../README.md) for the whole picture.

## Use it

```python
import phonenumber_ae as pn

pn.is_valid_number("US", "+1 201 555 0123")   # True
pn.is_possible_number("GB", "1212345678")     # True
pn.format("US", "2015550123", pn.NATIONAL)    # "(201) 555-0123"
pn.format("US", "2015550123", pn.E164)        # "+12015550123"
pn.number_type("US", "2015550123")            # pn.TYPE_FIXED_LINE
pn.country_code("JP")                         # "81"

# side-libraries
pn.carrier_name_for_number("GB", "7106000000")  # "O2"
pn.geo_description_for_number("US", "6502530000")  # "Mountain View, CA"
```

## Install it in your project

The binding is pure Python; it just needs the core `.so` at run time. The
loader finds it in this order: an explicit `pn._native.load(path)`,
`$LIBPHONENUMBER_AE_LIB`, the `phonenumber_ae/native/` dir a wheel ships, then the
OS loader's search path.

**Self-contained wheel (no Aether toolchain).** `aeb python/.dist.ae` bundles the
core *inside* the wheel, so an installed wheel needs no download and no
`LIBPHONENUMBER_AE_LIB` — the loader finds the bundled `phonenumber_ae/native/`
core. This is the no-toolchain path: install the wheel and go.

```sh
aeb core/.build.ae && aeb python/.dist.ae   # -> target/dist/phonenumber_ae-*.whl (core inside)
pip install target/dist/phonenumber_ae-*.whl
```

Building only this binding? Skip compiling the core — fetch the prebuilt one from
a [release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) with
`--overrideDep`, which relabels the wheel's core dependency to the fetch node:

```sh
# (a) grab the prebuilt core from the release (nothing to compile):
aeb python/.dist.ae \
    --overrideDep core/.build.ae=core/.getFromGitHub.ae

# (b) build the core from source instead:
aeb core/.build.ae && aeb python/.dist.ae
```

Same wheel either way — the core bytes are identical. See
[`docs/Prebuilt-Core-Packaging.md`](../docs/Prebuilt-Core-Packaging.md) for the
`--overrideDep` fetch-node flow.

**Point at an external core (optional).** If you'd rather supply the core
yourself — e.g. a shared one from a
[release](https://github.com/aether-lang-dev/libphonenumber-ae/releases) — set
`LIBPHONENUMBER_AE_LIB` to its path; the loader prefers it over the bundled one.

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb python/.tests.ae      # the 47-check conformance suite
```
