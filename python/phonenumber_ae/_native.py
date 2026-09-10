"""ctypes bindings for the phonenumber engine (libphonenumber_ae.so), ABI v2.

The ONLY place in the Python binding that knows the C ABI. Everything above it
(`_phonenumber.py`) is idiomatic Python over these symbols. No phone-number
logic lives here — the engine is `core/phonenumber.ae`, shared by every binding.

Library resolution: explicit path → $LIBPHONENUMBER_AE_LIB → native/ beside this
package → the OS loader's search path.
"""

import ctypes
import os
import sys

_LIB_NAME = {
    "darwin": "libphonenumber_ae.dylib",
    "win32": "phonenumber_ae.dll",
}.get(sys.platform, "libphonenumber_ae.so")

# ---- format styles (ABI constants — append only, never renumber) ----
E164 = 0
INTERNATIONAL = 1
NATIONAL = 2
RFC3966 = 3

# ---- number types ----
TYPE_UNKNOWN = -1
TYPE_FIXED_LINE = 0
TYPE_MOBILE = 1
TYPE_TOLL_FREE = 2
TYPE_PREMIUM_RATE = 3
TYPE_SHARED_COST = 4
TYPE_VOIP = 5
TYPE_PERSONAL_NUMBER = 6
TYPE_PAGER = 7
TYPE_UAN = 8
TYPE_VOICEMAIL = 9
TYPE_FIXED_LINE_OR_MOBILE = 10

# ---- ValidationResult (is_possible_number_with_reason) ----
VR_IS_POSSIBLE = 0
VR_IS_POSSIBLE_LOCAL_ONLY = 4
VR_INVALID_COUNTRY_CODE = 1
VR_TOO_SHORT = 2
VR_INVALID_LENGTH = 5
VR_TOO_LONG = 3

# ---- MatchType (is_number_match) ----
MATCH_NOT_A_NUMBER = 0
MATCH_NO_MATCH = 1
MATCH_SHORT_NSN = 2
MATCH_NSN = 3
MATCH_EXACT = 4

# ---- CountryCodeSource (pn_source) ----
SRC_FROM_NUMBER_WITH_PLUS = 1
SRC_FROM_NUMBER_WITH_IDD = 5
SRC_FROM_NUMBER_WITHOUT_PLUS = 10
SRC_FROM_DEFAULT_COUNTRY = 20

# ---- matcher leniency ----
LENIENCY_POSSIBLE = 0
LENIENCY_VALID = 1

# ---- ShortNumberCost (short_expected_cost) ----
COST_TOLL_FREE = 0
COST_STANDARD_RATE = 1
COST_PREMIUM_RATE = 2
COST_UNKNOWN = 3

_lib = None


def _candidates(explicit=None):
    if explicit:
        yield explicit
        return
    env = os.environ.get("LIBPHONENUMBER_AE_LIB")
    if env:
        yield env
    here = os.path.dirname(os.path.abspath(__file__))
    yield os.path.join(here, "native", _LIB_NAME)
    yield _LIB_NAME


def load(path=None):
    """Load the engine .so, caching it process-wide. Returns the CDLL."""
    global _lib
    if _lib is not None and path is None:
        return _lib
    last = None
    for cand in _candidates(path):
        try:
            lib = ctypes.CDLL(cand)
            break
        except OSError as exc:
            last = exc
    else:
        raise OSError(
            "could not load the phonenumber engine ({}). Set "
            "LIBPHONENUMBER_AE_LIB to its absolute path. Last error: {}".format(
                _LIB_NAME, last))
    _declare(lib)
    if path is None:
        _lib = lib
    return lib


def _declare(lib):
    P = ctypes.c_void_p
    S = ctypes.c_char_p
    I = ctypes.c_int
    sigs = {
        "aether_pn_embed_abi_version": ([], I),
        "aether_pn_embed_free_string": ([P], None),
        # metadata
        "aether_pn_embed_country_code": ([S], P),
        "aether_pn_embed_example_number": ([S], P),
        "aether_pn_embed_example_number_for_type": ([S, I], P),
        "aether_pn_embed_invalid_example_number": ([S], P),
        "aether_pn_embed_possible_lengths": ([S], P),
        "aether_pn_embed_region_code_for_country_code": ([S], P),
        "aether_pn_embed_is_nanpa_country": ([S], I),
        "aether_pn_embed_ndd_prefix_for_region": ([S, I], P),
        "aether_pn_embed_region_count": ([], I),
        "aether_pn_embed_region_at": ([I], P),
        "aether_pn_embed_cc_region_count": ([S], I),
        "aether_pn_embed_cc_region_at": ([S, I], P),
        # parse + accessors
        "aether_pn_embed_parse": ([S, S], P),
        "aether_pn_embed_national_number": ([S, S], P),
        "aether_pn_embed_pn_region": ([S], P),
        "aether_pn_embed_pn_country_code": ([S], P),
        "aether_pn_embed_pn_national_number": ([S], P),
        "aether_pn_embed_pn_extension": ([S], P),
        "aether_pn_embed_pn_italian_leading_zero": ([S], I),
        "aether_pn_embed_pn_source": ([S], I),
        "aether_pn_embed_pn_error": ([S], P),
        "aether_pn_embed_region_code_for_number": ([S], P),
        "aether_pn_embed_national_significant_number": ([S], P),
        "aether_pn_embed_length_of_ndc": ([S], I),
        "aether_pn_embed_length_of_area_code": ([S], I),
        "aether_pn_embed_is_geographical": ([S], I),
        # validation
        "aether_pn_embed_is_possible_number": ([S, S], I),
        "aether_pn_embed_is_possible_number_with_reason": ([S, S], I),
        "aether_pn_embed_is_valid_number": ([S, S], I),
        "aether_pn_embed_is_valid_number_for_region": ([S, S], I),
        "aether_pn_embed_number_type": ([S, S], I),
        "aether_pn_embed_can_be_internationally_dialled": ([S, S], I),
        # formatting
        "aether_pn_embed_format": ([S, S, I], P),
        "aether_pn_embed_format_out_of_country": ([S, S, S], P),
        "aether_pn_embed_format_in_original": ([S, S], P),
        # relations / helpers
        "aether_pn_embed_is_number_match": ([S, S], I),
        "aether_pn_embed_truncate_too_long": ([S, S], P),
        "aether_pn_embed_normalize_digits_only": ([S], P),
        "aether_pn_embed_convert_alpha_characters": ([S], P),
        "aether_pn_embed_is_alpha_number": ([S], I),
        # AsYouType
        "aether_pn_embed_ayt_new": ([S], P),
        "aether_pn_embed_ayt_input": ([S, S], P),
        "aether_pn_embed_ayt_result": ([S], P),
        "aether_pn_embed_ayt_clear": ([S], P),
        # matcher
        "aether_pn_embed_matcher_count": ([S, S, I], I),
        "aether_pn_embed_matcher_start": ([S, S, I, I], I),
        "aether_pn_embed_matcher_end": ([S, S, I, I], I),
        "aether_pn_embed_matcher_raw": ([S, S, I, I], P),
        # ShortNumberInfo
        "aether_pn_embed_short_is_possible": ([S, S], I),
        "aether_pn_embed_short_is_valid": ([S, S], I),
        "aether_pn_embed_short_is_emergency": ([S, S], I),
        "aether_pn_embed_short_connects_to_emergency": ([S, S], I),
        "aether_pn_embed_short_is_carrier_specific": ([S, S], I),
        "aether_pn_embed_short_is_sms_service": ([S, S], I),
        "aether_pn_embed_short_expected_cost": ([S, S], I),
        "aether_pn_embed_short_example_number": ([S], P),
    }
    for name, (argtypes, restype) in sigs.items():
        fn = getattr(lib, name)
        fn.argtypes = argtypes
        fn.restype = restype


def take_string(lib, ptr):
    """Copy an ABI-returned string out and free it through the ABI."""
    if not ptr:
        return ""
    try:
        return ctypes.cast(ptr, ctypes.c_char_p).value.decode("utf-8", "replace")
    finally:
        lib.aether_pn_embed_free_string(ptr)
