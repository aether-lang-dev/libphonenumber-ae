# phonenumber_ae (Python)

A thin Python binding over the shared, pure-Aether libphonenumber engine.

```python
import phonenumber_ae as pn

pn.is_valid_number("US", "+1 201 555 0123")   # True
pn.is_possible_number("GB", "1212345678")     # True
pn.format("US", "2015550123", pn.NATIONAL)    # "(201) 555-0123"
pn.format("US", "2015550123", pn.E164)        # "+12015550123"
pn.number_type("US", "2015550123")            # pn.TYPE_FIXED_LINE
pn.country_code("JP")                         # "81"
```

The binding carries **no** phone-number logic — validation, number typing and
formatting all live in the one shared engine (`core/phonenumber.ae`), compiled
from Google libphonenumber's own metadata. Every language binding in this repo
is marshalling over the same `libphonenumber_ae.so`.

## Finding the engine

`_native.load()` looks for the shared library in this order:

1. an explicit path you pass to `load(path)`
2. `$LIBPHONENUMBER_AE_LIB`
3. `phonenumber_ae/native/` bundled next to the package (what a wheel ships)
4. the OS loader's search path

## Testing

```
LIBPHONENUMBER_AE_LIB=/path/to/libphonenumber_ae.so \
  PYTHONPATH=. PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest test -q
```

Or via aeb, which builds the engine and points the loader at it:

```
aeb python/.tests.ae
```
