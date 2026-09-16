# phonenumber_ae — Python

A thin Python binding over the shared, pure-Aether libphonenumber engine. All the
phone logic lives in the one engine (`core/phonenumber.ae`); this binding is just
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

Build the wheel (from the repo root), then install it — the engine `.so` is
bundled inside, so nothing else is needed at runtime:

```sh
aeb core/.build.ae && aeb python/.dist.ae   # -> target/dist/phonenumber_ae-*.whl
pip install target/dist/phonenumber_ae-*.whl
```

The wheel is current-OS-only (it bundles this platform's `.so`). The loader finds
the engine in this order: an explicit `pn._native.load(path)`,
`$LIBPHONENUMBER_AE_LIB`, the `phonenumber_ae/native/` dir a wheel ships, then the
OS loader's search path — so an installed wheel needs no configuration.

## Develop / test

From the repo, `aeb` builds the engine and runs the suite against the source
tree:

```sh
aeb python/.tests.ae      # the 47-check conformance suite
```
