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

**With a downloaded core (no Aether toolchain).** Install the package, download
the core for your platform, and point at it:

```sh
pip install target/dist/phonenumber_ae-*.whl   # or the published package, when there is one
# get-core.sh downloads the core for this platform and prints its path:
export LIBPHONENUMBER_AE_LIB="$(curl -fsSL https://raw.githubusercontent.com/aether-lang-dev/libphonenumber-ae/main/get-core.sh | sh)"
```

**Self-contained wheel (built here).** `aeb <lang>/.dist.ae` bundles the freshly
built core *inside* the wheel, so an installed wheel needs no configuration —
current-OS-only:

```sh
aeb core/.build.ae && aeb python/.dist.ae   # -> target/dist/phonenumber_ae-*.whl (core inside)
pip install target/dist/phonenumber_ae-*.whl
```

## Develop / test

From the repo, `aeb` builds the core and runs the suite against the source
tree:

```sh
aeb python/.tests.ae      # the 47-check conformance suite
```
