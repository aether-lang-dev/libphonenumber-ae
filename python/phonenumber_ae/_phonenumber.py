"""Idiomatic Python surface over the phonenumber engine (ABI v2).

Carries no phone-number logic — every function marshals to an
`aether_pn_embed_*` call in `_native.py`.
"""

from . import _native
from ._native import (
    E164, INTERNATIONAL, NATIONAL, RFC3966,
    LENIENCY_POSSIBLE, LENIENCY_VALID,
)


def _enc(s):
    return (s or "").encode("utf-8")


def _lib():
    return _native.load()


def _s(fn, *args):
    lib = _lib()
    return _native.take_string(lib, getattr(lib, fn)(*args))


# ---- metadata ----

def country_code(region):
    return _s("aether_pn_embed_country_code", _enc(region))


def example_number(region):
    return _s("aether_pn_embed_example_number", _enc(region))


def example_number_for_type(region, ntype):
    return _s("aether_pn_embed_example_number_for_type", _enc(region), int(ntype))


def invalid_example_number(region):
    return _s("aether_pn_embed_invalid_example_number", _enc(region))


def possible_lengths(region):
    return _s("aether_pn_embed_possible_lengths", _enc(region))


def region_code_for_country_code(cc):
    return _s("aether_pn_embed_region_code_for_country_code", _enc(str(cc)))


def is_nanpa_country(region):
    return bool(_lib().aether_pn_embed_is_nanpa_country(_enc(region)))


def ndd_prefix_for_region(region, strip_non_digits=False):
    return _s("aether_pn_embed_ndd_prefix_for_region", _enc(region), 1 if strip_non_digits else 0)


def region_count():
    return _lib().aether_pn_embed_region_count()


def region_at(index):
    return _s("aether_pn_embed_region_at", int(index))


def regions():
    return [region_at(i) for i in range(region_count())]


def regions_for_country_code(cc):
    lib = _lib()
    n = lib.aether_pn_embed_cc_region_count(_enc(str(cc)))
    return [_s("aether_pn_embed_cc_region_at", _enc(str(cc)), i) for i in range(n)]


# ---- parsed number ----

class ParsedNumber:
    """A parsed phone number. Wraps the caller-owned parsed-number string the
    ABI returns; its fields are read on demand."""

    __slots__ = ("_pn",)

    def __init__(self, pn_string):
        self._pn = pn_string

    @property
    def region(self):
        return _s("aether_pn_embed_pn_region", _enc(self._pn))

    @property
    def country_code(self):
        return _s("aether_pn_embed_pn_country_code", _enc(self._pn))

    @property
    def national_number(self):
        return _s("aether_pn_embed_pn_national_number", _enc(self._pn))

    @property
    def extension(self):
        return _s("aether_pn_embed_pn_extension", _enc(self._pn))

    @property
    def italian_leading_zero(self):
        return bool(_lib().aether_pn_embed_pn_italian_leading_zero(_enc(self._pn)))

    @property
    def source(self):
        return _lib().aether_pn_embed_pn_source(_enc(self._pn))

    @property
    def error(self):
        return _s("aether_pn_embed_pn_error", _enc(self._pn))

    @property
    def region_code(self):
        return _s("aether_pn_embed_region_code_for_number", _enc(self._pn))

    @property
    def national_significant_number(self):
        return _s("aether_pn_embed_national_significant_number", _enc(self._pn))

    @property
    def length_of_ndc(self):
        return _lib().aether_pn_embed_length_of_ndc(_enc(self._pn))

    @property
    def length_of_area_code(self):
        return _lib().aether_pn_embed_length_of_area_code(_enc(self._pn))

    @property
    def is_geographical(self):
        return bool(_lib().aether_pn_embed_is_geographical(_enc(self._pn)))


def parse(number, region):
    return ParsedNumber(_s("aether_pn_embed_parse", _enc(number), _enc(region)))


def national_number(region, number):
    return _s("aether_pn_embed_national_number", _enc(region), _enc(number))


# ---- validation ----

def is_possible_number(region, number):
    return bool(_lib().aether_pn_embed_is_possible_number(_enc(region), _enc(number)))


def is_possible_number_with_reason(region, number):
    return _lib().aether_pn_embed_is_possible_number_with_reason(_enc(region), _enc(number))


def is_valid_number(region, number):
    return bool(_lib().aether_pn_embed_is_valid_number(_enc(region), _enc(number)))


def is_valid_number_for_region(number, region):
    return bool(_lib().aether_pn_embed_is_valid_number_for_region(_enc(number), _enc(region)))


def number_type(region, number):
    return _lib().aether_pn_embed_number_type(_enc(region), _enc(number))


def can_be_internationally_dialled(region, number):
    return bool(_lib().aether_pn_embed_can_be_internationally_dialled(_enc(region), _enc(number)))


# ---- formatting ----

def format(region, number, style=NATIONAL):
    return _s("aether_pn_embed_format", _enc(region), _enc(number), int(style))


def format_national(region, number):
    return format(region, number, NATIONAL)


def format_international(region, number):
    return format(region, number, INTERNATIONAL)


def format_e164(region, number):
    return format(region, number, E164)


def format_rfc3966(region, number):
    return format(region, number, RFC3966)


def format_out_of_country(region, number, calling_from):
    return _s("aether_pn_embed_format_out_of_country", _enc(region), _enc(number), _enc(calling_from))


def format_in_original(parsed, calling_from):
    return _s("aether_pn_embed_format_in_original", _enc(parsed._pn), _enc(calling_from))


# ---- relations / helpers ----

def is_number_match(a, b):
    return _lib().aether_pn_embed_is_number_match(_enc(a), _enc(b))


def truncate_too_long(region, number):
    return _s("aether_pn_embed_truncate_too_long", _enc(region), _enc(number))


def normalize_digits_only(s):
    return _s("aether_pn_embed_normalize_digits_only", _enc(s))


def convert_alpha_characters(s):
    return _s("aether_pn_embed_convert_alpha_characters", _enc(s))


def is_alpha_number(s):
    return bool(_lib().aether_pn_embed_is_alpha_number(_enc(s)))


def abi_version():
    return _lib().aether_pn_embed_abi_version()


# ---- AsYouTypeFormatter ----

class AsYouTypeFormatter:
    """Formats a number as it is typed, digit by digit."""

    __slots__ = ("_state",)

    def __init__(self, region):
        self._state = _s("aether_pn_embed_ayt_new", _enc(region))

    def input_digit(self, ch):
        """Feed one character; return the formatted-so-far string."""
        self._state = _s("aether_pn_embed_ayt_input", _enc(self._state), _enc(str(ch)))
        return self.result()

    def result(self):
        return _s("aether_pn_embed_ayt_result", _enc(self._state))

    def clear(self):
        self._state = _s("aether_pn_embed_ayt_clear", _enc(self._state))


# ---- PhoneNumberMatcher ----

class Match:
    __slots__ = ("start", "end", "raw")

    def __init__(self, start, end, raw):
        self.start = start
        self.end = end
        self.raw = raw


def find_numbers(text, region, leniency=LENIENCY_VALID):
    """Find phone numbers in free text. Returns a list of Match."""
    lib = _lib()
    n = lib.aether_pn_embed_matcher_count(_enc(text), _enc(region), int(leniency))
    out = []
    for i in range(n):
        start = lib.aether_pn_embed_matcher_start(_enc(text), _enc(region), int(leniency), i)
        end = lib.aether_pn_embed_matcher_end(_enc(text), _enc(region), int(leniency), i)
        raw = _s("aether_pn_embed_matcher_raw", _enc(text), _enc(region), int(leniency), i)
        out.append(Match(start, end, raw))
    return out


# ---- ShortNumberInfo (short / emergency numbers) ----

def short_is_possible(region, number):
    return bool(_lib().aether_pn_embed_short_is_possible(_enc(region), _enc(number)))


def short_is_valid(region, number):
    return bool(_lib().aether_pn_embed_short_is_valid(_enc(region), _enc(number)))


def is_emergency_number(region, number):
    return bool(_lib().aether_pn_embed_short_is_emergency(_enc(region), _enc(number)))


def connects_to_emergency_number(region, number):
    return bool(_lib().aether_pn_embed_short_connects_to_emergency(_enc(region), _enc(number)))


def short_is_carrier_specific(region, number):
    return bool(_lib().aether_pn_embed_short_is_carrier_specific(_enc(region), _enc(number)))


def short_is_sms_service(region, number):
    return bool(_lib().aether_pn_embed_short_is_sms_service(_enc(region), _enc(number)))


def short_expected_cost(region, number):
    return _lib().aether_pn_embed_short_expected_cost(_enc(region), _enc(number))


def short_example_number(region):
    return _s("aether_pn_embed_short_example_number", _enc(region))
