/* erlang/c_src/phonenumber_ae_nif.c — the canonical BEAM binding (ABI v7).
 *
 * ONE NIF, shared by all three BEAM languages. Erlang loads it directly;
 * Elixir `defdelegate`s to it; Gleam reaches it with `@external(erlang, ...)`.
 * There is no second copy of this file anywhere in the monorepo — elixir/ and
 * gleam/ build.dep the erlang/ node and load THIS compiled module over the
 * BEAM, found via ERL_LIBS.
 *
 * NO PHONE-NUMBER LOGIC LIVES HERE. Every function marshals BEAM terms to an
 * `aether_pn_embed_*` call across the flat C ABI described in core/embed.ae
 * (docs/abi.md — 66 symbols, full PhoneNumberUtil parity plus ShortNumberInfo,
 * TimeZones, Carrier and Geocoder).
 *
 * ## The ONE ownership rule
 *
 * Every char* the ABI returns is CALLER-OWNED and must go back through
 * aether_pn_embed_free_string. `take_binary` below is the only path a returned
 * string takes out of this file, so the free cannot be forgotten. This holds
 * for the v2 additions too: parse, the pn_* accessors, format_*, the AsYouType
 * state strings, matcher_raw — every returned char* is copied then freed here.
 *
 * ## No handle, no callbacks
 *
 * The ABI has no opaque handles. A parsed number and an AsYouType state are
 * themselves caller-owned STRINGS: the binding gets one back, passes it to
 * accessor calls, and frees it like any other returned string. So this file is
 * still pure binary<->C-string marshalling plus copy-then-free on returns — no
 * enif_resource, no dtor, no callback plumbing.
 *
 * ## Dirty schedulers
 *
 * Every call here is a small table lookup / pattern match / short scan in the
 * engine, well under the ~1ms a normal NIF may occupy a scheduler. None is
 * flagged dirty.
 */
#include <erl_nif.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#ifdef _WIN32
#  include <windows.h>
#  define PN_DLOPEN(p)      ((void *)LoadLibraryA(p))
#  define PN_DLSYM(h, n)    ((void *)GetProcAddress((HMODULE)(h), (n)))
#  define PN_LIB_NAME       "phonenumber_ae.dll"
#else
#  include <dlfcn.h>
#  define PN_DLOPEN(p)      dlopen((p), RTLD_NOW | RTLD_LOCAL)
#  define PN_DLSYM(h, n)    dlsym((h), (n))
#  ifdef __APPLE__
#    define PN_LIB_NAME     "libphonenumber_ae.dylib"
#  else
#    define PN_LIB_NAME     "libphonenumber_ae.so"
#  endif
#endif

/* ---- the C ABI (core/embed.ae), resolved once at load ---- */

static int   (*pn_abi_version)(void);
static void  (*pn_free_string)(char *);
/* metadata */
static char *(*pn_country_code)(const char *);
static char *(*pn_example_number)(const char *);
static char *(*pn_example_number_for_type)(const char *, int);
static char *(*pn_invalid_example_number)(const char *);
static char *(*pn_possible_lengths)(const char *);
static char *(*pn_region_code_for_country_code)(const char *);
static int   (*pn_is_nanpa_country)(const char *);
static char *(*pn_ndd_prefix_for_region)(const char *, int);
static int   (*pn_region_count)(void);
static char *(*pn_region_at)(int);
static int   (*pn_cc_region_count)(const char *);
static char *(*pn_cc_region_at)(const char *, int);
/* parse + accessors */
static char *(*pn_parse)(const char *, const char *);
static char *(*pn_national_number)(const char *, const char *);
static char *(*pn_pn_region)(const char *);
static char *(*pn_pn_country_code)(const char *);
static char *(*pn_pn_national_number)(const char *);
static char *(*pn_pn_extension)(const char *);
static int   (*pn_pn_italian_leading_zero)(const char *);
static int   (*pn_pn_source)(const char *);
static char *(*pn_pn_error)(const char *);
static char *(*pn_region_code_for_number)(const char *);
static char *(*pn_national_significant_number)(const char *);
static int   (*pn_length_of_ndc)(const char *);
static int   (*pn_length_of_area_code)(const char *);
static int   (*pn_is_geographical)(const char *);
/* validation */
static int   (*pn_is_possible_number)(const char *, const char *);
static int   (*pn_is_possible_number_with_reason)(const char *, const char *);
static int   (*pn_is_valid_number)(const char *, const char *);
static int   (*pn_is_valid_number_for_region)(const char *, const char *);
static int   (*pn_number_type)(const char *, const char *);
static int   (*pn_can_be_internationally_dialled)(const char *, const char *);
/* formatting */
static char *(*pn_format)(const char *, const char *, int);
static char *(*pn_format_out_of_country)(const char *, const char *, const char *);
static char *(*pn_format_in_original)(const char *, const char *);
/* relations / helpers */
static int   (*pn_is_number_match)(const char *, const char *);
static char *(*pn_truncate_too_long)(const char *, const char *);
static char *(*pn_normalize_digits_only)(const char *);
static char *(*pn_convert_alpha_characters)(const char *);
static int   (*pn_is_alpha_number)(const char *);
/* AsYouTypeFormatter */
static char *(*pn_ayt_new)(const char *);
static char *(*pn_ayt_input)(const char *, const char *);
static char *(*pn_ayt_result)(const char *);
static char *(*pn_ayt_clear)(const char *);
/* matcher */
static int   (*pn_matcher_count)(const char *, const char *, int);
static int   (*pn_matcher_start)(const char *, const char *, int, int);
static int   (*pn_matcher_end)(const char *, const char *, int, int);
static char *(*pn_matcher_raw)(const char *, const char *, int, int);
/* ShortNumberInfo */
static int   (*pn_short_is_possible)(const char *, const char *);
static int   (*pn_short_is_valid)(const char *, const char *);
static int   (*pn_short_is_emergency)(const char *, const char *);
static int   (*pn_short_connects_to_emergency)(const char *, const char *);
static int   (*pn_short_is_carrier_specific)(const char *, const char *);
static int   (*pn_short_is_sms_service)(const char *, const char *);
static int   (*pn_short_expected_cost)(const char *, const char *);
static char *(*pn_short_example_number)(const char *);
/* PhoneNumberToTimeZonesMapper */
static int   (*pn_tz_count)(const char *, const char *);
static char *(*pn_tz_at)(const char *, const char *, int);
static char *(*pn_tz_all)(const char *, const char *);
static char *(*pn_tz_unknown)(void);
/* PhoneNumberToCarrierMapper (v7: a trailing lang arg) */
static char *(*pn_carrier_name)(const char *, const char *, const char *);
static char *(*pn_carrier_name_for_valid)(const char *, const char *, const char *);
/* PhoneNumberOfflineGeocoder (v7: a trailing lang arg) */
static char *(*pn_geo_description)(const char *, const char *, const char *);
static char *(*pn_geo_description_for_valid)(const char *, const char *, const char *);

static void *pn_lib = NULL;

/* ---- small helpers ---- */

/* Copy a BEAM binary/iolist argument into a NUL-terminated C string.
 *
 * The ABI is NUL-terminated char*, so a binary with an interior NUL cannot be
 * represented; we stop at it rather than pass a buffer whose C length disagrees
 * with its BEAM length. Returns NULL on a bad term or OOM; the caller frees
 * with enif_free. */
static char *term_to_cstr(ErlNifEnv *env, ERL_NIF_TERM term)
{
    ErlNifBinary bin;
    char *out;

    if (!enif_inspect_iolist_as_binary(env, term, &bin)) {
        return NULL;
    }
    out = (char *)enif_alloc(bin.size + 1);
    if (!out) {
        return NULL;
    }
    if (bin.size) {
        memcpy(out, bin.data, bin.size);
    }
    out[bin.size] = '\0';
    return out;
}

/* Turn an ABI-returned, caller-owned char* into a BEAM binary and free it
 * through the ABI. EVERY string result from the engine goes through here —
 * that is what makes the free impossible to forget. */
static ERL_NIF_TERM take_binary(ErlNifEnv *env, char *s)
{
    ERL_NIF_TERM out;
    size_t len;
    unsigned char *buf;

    if (!s) {
        /* An empty binary, not a crash. The ABI returns an owned "" rather than
         * NULL, but a defensive branch here costs nothing. */
        enif_make_new_binary(env, 0, &out);
        return out;
    }
    len = strlen(s);
    buf = enif_make_new_binary(env, len, &out);
    if (buf && len) {
        memcpy(buf, s, len);
    }
    pn_free_string(s);
    return out;
}

/* ---- shared marshalling bodies ---- */

/* (string) -> string. */
static ERL_NIF_TERM do_str_str(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                               char *(*fn)(const char *))
{
    char *a, *out;
    a = term_to_cstr(env, argv[0]);
    if (!a) return enif_make_badarg(env);
    out = fn(a);
    enif_free(a);
    return take_binary(env, out);
}

/* (string) -> int. */
static ERL_NIF_TERM do_str_int(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                               int (*fn)(const char *))
{
    char *a;
    int rc;
    a = term_to_cstr(env, argv[0]);
    if (!a) return enif_make_badarg(env);
    rc = fn(a);
    enif_free(a);
    return enif_make_int(env, rc);
}

/* (string, string) -> string. */
static ERL_NIF_TERM do_ss_str(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                              char *(*fn)(const char *, const char *))
{
    char *a, *b, *out;
    a = term_to_cstr(env, argv[0]);
    if (!a) return enif_make_badarg(env);
    b = term_to_cstr(env, argv[1]);
    if (!b) { enif_free(a); return enif_make_badarg(env); }
    out = fn(a, b);
    enif_free(a);
    enif_free(b);
    return take_binary(env, out);
}

/* (string, string, string) -> string. */
static ERL_NIF_TERM do_sss_str(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                               char *(*fn)(const char *, const char *, const char *))
{
    char *a, *b, *c, *out;
    a = term_to_cstr(env, argv[0]);
    if (!a) return enif_make_badarg(env);
    b = term_to_cstr(env, argv[1]);
    if (!b) { enif_free(a); return enif_make_badarg(env); }
    c = term_to_cstr(env, argv[2]);
    if (!c) { enif_free(a); enif_free(b); return enif_make_badarg(env); }
    out = fn(a, b, c);
    enif_free(a);
    enif_free(b);
    enif_free(c);
    return take_binary(env, out);
}

/* (string, string) -> int. */
static ERL_NIF_TERM do_ss_int(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                              int (*fn)(const char *, const char *))
{
    char *a, *b;
    int rc;
    a = term_to_cstr(env, argv[0]);
    if (!a) return enif_make_badarg(env);
    b = term_to_cstr(env, argv[1]);
    if (!b) { enif_free(a); return enif_make_badarg(env); }
    rc = fn(a, b);
    enif_free(a);
    enif_free(b);
    return enif_make_int(env, rc);
}

/* (string, int) -> string. */
static ERL_NIF_TERM do_si_str(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                              char *(*fn)(const char *, int))
{
    char *a, *out;
    int i;
    a = term_to_cstr(env, argv[0]);
    if (!a) return enif_make_badarg(env);
    if (!enif_get_int(env, argv[1], &i)) { enif_free(a); return enif_make_badarg(env); }
    out = fn(a, i);
    enif_free(a);
    return take_binary(env, out);
}

/* ---- metadata ---- */

static ERL_NIF_TERM nif_country_code(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_country_code); }

static ERL_NIF_TERM nif_example_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_example_number); }

static ERL_NIF_TERM nif_example_number_for_type(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_si_str(env, argv, pn_example_number_for_type); }

static ERL_NIF_TERM nif_invalid_example_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_invalid_example_number); }

static ERL_NIF_TERM nif_possible_lengths(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_possible_lengths); }

static ERL_NIF_TERM nif_region_code_for_country_code(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_region_code_for_country_code); }

static ERL_NIF_TERM nif_is_nanpa_country(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_is_nanpa_country); }

static ERL_NIF_TERM nif_ndd_prefix_for_region(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_si_str(env, argv, pn_ndd_prefix_for_region); }

static ERL_NIF_TERM nif_cc_region_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_cc_region_count); }

static ERL_NIF_TERM nif_cc_region_at(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_si_str(env, argv, pn_cc_region_at); }

/* ---- parse + accessors ---- */

static ERL_NIF_TERM nif_parse(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_str(env, argv, pn_parse); }

static ERL_NIF_TERM nif_national_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_str(env, argv, pn_national_number); }

static ERL_NIF_TERM nif_pn_region(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_pn_region); }

static ERL_NIF_TERM nif_pn_country_code(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_pn_country_code); }

static ERL_NIF_TERM nif_pn_national_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_pn_national_number); }

static ERL_NIF_TERM nif_pn_extension(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_pn_extension); }

static ERL_NIF_TERM nif_pn_italian_leading_zero(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_pn_italian_leading_zero); }

static ERL_NIF_TERM nif_pn_source(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_pn_source); }

static ERL_NIF_TERM nif_pn_error(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_pn_error); }

static ERL_NIF_TERM nif_region_code_for_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_region_code_for_number); }

static ERL_NIF_TERM nif_national_significant_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_national_significant_number); }

static ERL_NIF_TERM nif_length_of_ndc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_length_of_ndc); }

static ERL_NIF_TERM nif_length_of_area_code(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_length_of_area_code); }

static ERL_NIF_TERM nif_is_geographical(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_is_geographical); }

/* ---- validation ---- */

static ERL_NIF_TERM nif_is_possible_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_is_possible_number); }

static ERL_NIF_TERM nif_is_possible_number_with_reason(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_is_possible_number_with_reason); }

static ERL_NIF_TERM nif_is_valid_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_is_valid_number); }

static ERL_NIF_TERM nif_is_valid_number_for_region(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_is_valid_number_for_region); }

static ERL_NIF_TERM nif_number_type(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_number_type); }

static ERL_NIF_TERM nif_can_be_internationally_dialled(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_can_be_internationally_dialled); }

/* ---- formatting ---- */

static ERL_NIF_TERM nif_format(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char *region, *input, *out;
    int fmt;
    (void)argc;

    region = term_to_cstr(env, argv[0]);
    if (!region) return enif_make_badarg(env);
    input = term_to_cstr(env, argv[1]);
    if (!input) { enif_free(region); return enif_make_badarg(env); }
    if (!enif_get_int(env, argv[2], &fmt)) {
        enif_free(region);
        enif_free(input);
        return enif_make_badarg(env);
    }
    out = pn_format(region, input, fmt);
    enif_free(region);
    enif_free(input);
    return take_binary(env, out);
}

static ERL_NIF_TERM nif_format_out_of_country(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char *region, *input, *from, *out;
    (void)argc;

    region = term_to_cstr(env, argv[0]);
    if (!region) return enif_make_badarg(env);
    input = term_to_cstr(env, argv[1]);
    if (!input) { enif_free(region); return enif_make_badarg(env); }
    from = term_to_cstr(env, argv[2]);
    if (!from) { enif_free(region); enif_free(input); return enif_make_badarg(env); }
    out = pn_format_out_of_country(region, input, from);
    enif_free(region);
    enif_free(input);
    enif_free(from);
    return take_binary(env, out);
}

static ERL_NIF_TERM nif_format_in_original(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_str(env, argv, pn_format_in_original); }

/* ---- relations / helpers ---- */

static ERL_NIF_TERM nif_is_number_match(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_is_number_match); }

static ERL_NIF_TERM nif_truncate_too_long(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_str(env, argv, pn_truncate_too_long); }

static ERL_NIF_TERM nif_normalize_digits_only(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_normalize_digits_only); }

static ERL_NIF_TERM nif_convert_alpha_characters(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_convert_alpha_characters); }

static ERL_NIF_TERM nif_is_alpha_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_int(env, argv, pn_is_alpha_number); }

/* ---- AsYouTypeFormatter (state threaded as a caller-owned string) ---- */

static ERL_NIF_TERM nif_ayt_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_ayt_new); }

static ERL_NIF_TERM nif_ayt_input(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_str(env, argv, pn_ayt_input); }

static ERL_NIF_TERM nif_ayt_result(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_ayt_result); }

static ERL_NIF_TERM nif_ayt_clear(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_ayt_clear); }

/* ---- matcher / findNumbers ---- */

/* (text, region, leniency) -> int. */
static ERL_NIF_TERM nif_matcher_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char *text, *region;
    int len, rc;
    (void)argc;

    text = term_to_cstr(env, argv[0]);
    if (!text) return enif_make_badarg(env);
    region = term_to_cstr(env, argv[1]);
    if (!region) { enif_free(text); return enif_make_badarg(env); }
    if (!enif_get_int(env, argv[2], &len)) { enif_free(text); enif_free(region); return enif_make_badarg(env); }
    rc = pn_matcher_count(text, region, len);
    enif_free(text);
    enif_free(region);
    return enif_make_int(env, rc);
}

/* Shared body for (text, region, leniency, idx) -> int (start/end). */
static ERL_NIF_TERM do_matcher_int(ErlNifEnv *env, const ERL_NIF_TERM argv[],
                                   int (*fn)(const char *, const char *, int, int))
{
    char *text, *region;
    int len, idx, rc;

    text = term_to_cstr(env, argv[0]);
    if (!text) return enif_make_badarg(env);
    region = term_to_cstr(env, argv[1]);
    if (!region) { enif_free(text); return enif_make_badarg(env); }
    if (!enif_get_int(env, argv[2], &len) || !enif_get_int(env, argv[3], &idx)) {
        enif_free(text); enif_free(region); return enif_make_badarg(env);
    }
    rc = fn(text, region, len, idx);
    enif_free(text);
    enif_free(region);
    return enif_make_int(env, rc);
}

static ERL_NIF_TERM nif_matcher_start(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_matcher_int(env, argv, pn_matcher_start); }

static ERL_NIF_TERM nif_matcher_end(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_matcher_int(env, argv, pn_matcher_end); }

static ERL_NIF_TERM nif_matcher_raw(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char *text, *region, *out;
    int len, idx;
    (void)argc;

    text = term_to_cstr(env, argv[0]);
    if (!text) return enif_make_badarg(env);
    region = term_to_cstr(env, argv[1]);
    if (!region) { enif_free(text); return enif_make_badarg(env); }
    if (!enif_get_int(env, argv[2], &len) || !enif_get_int(env, argv[3], &idx)) {
        enif_free(text); enif_free(region); return enif_make_badarg(env);
    }
    out = pn_matcher_raw(text, region, len, idx);
    enif_free(text);
    enif_free(region);
    return take_binary(env, out);
}

/* ---- ShortNumberInfo (short / emergency numbers) ---- */

static ERL_NIF_TERM nif_short_is_possible(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_is_possible); }

static ERL_NIF_TERM nif_short_is_valid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_is_valid); }

static ERL_NIF_TERM nif_short_is_emergency(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_is_emergency); }

static ERL_NIF_TERM nif_short_connects_to_emergency(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_connects_to_emergency); }

static ERL_NIF_TERM nif_short_is_carrier_specific(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_is_carrier_specific); }

static ERL_NIF_TERM nif_short_is_sms_service(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_is_sms_service); }

static ERL_NIF_TERM nif_short_expected_cost(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_short_expected_cost); }

static ERL_NIF_TERM nif_short_example_number(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_str_str(env, argv, pn_short_example_number); }

/* ---- PhoneNumberToTimeZonesMapper (timezone lookup) ---- */

static ERL_NIF_TERM nif_tz_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_int(env, argv, pn_tz_count); }

/* (string, string, int) -> string, for tz_at. */
static ERL_NIF_TERM nif_tz_at(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    char *region, *input, *out;
    int idx;
    (void)argc;

    region = term_to_cstr(env, argv[0]);
    if (!region) return enif_make_badarg(env);
    input = term_to_cstr(env, argv[1]);
    if (!input) { enif_free(region); return enif_make_badarg(env); }
    if (!enif_get_int(env, argv[2], &idx)) {
        enif_free(region);
        enif_free(input);
        return enif_make_badarg(env);
    }
    out = pn_tz_at(region, input, idx);
    enif_free(region);
    enif_free(input);
    return take_binary(env, out);
}

static ERL_NIF_TERM nif_tz_all(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_ss_str(env, argv, pn_tz_all); }

static ERL_NIF_TERM nif_tz_unknown(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; (void)argv; return take_binary(env, pn_tz_unknown()); }

/* ---- PhoneNumberToCarrierMapper (localized carrier names) ---- */

static ERL_NIF_TERM nif_carrier_name(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_sss_str(env, argv, pn_carrier_name); }

static ERL_NIF_TERM nif_carrier_name_for_valid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_sss_str(env, argv, pn_carrier_name_for_valid); }

/* ---- PhoneNumberOfflineGeocoder (localized geographic descriptions) ---- */

static ERL_NIF_TERM nif_geo_description(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_sss_str(env, argv, pn_geo_description); }

static ERL_NIF_TERM nif_geo_description_for_valid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{ (void)argc; return do_sss_str(env, argv, pn_geo_description_for_valid); }

/* ---- region enumeration ---- */

static ERL_NIF_TERM nif_region_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc; (void)argv;
    return enif_make_int(env, pn_region_count());
}

static ERL_NIF_TERM nif_region_at(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int idx;
    (void)argc;

    if (!enif_get_int(env, argv[0], &idx)) {
        return enif_make_badarg(env);
    }
    return take_binary(env, pn_region_at(idx));
}

/* regions/0 builds the whole list in C rather than exposing region_at/1 to a
 * BEAM loop, which would pay a NIF crossing per entry. One crossing, one pass'
 * worth of allocation; every char* is freed through take_binary as we go. */
static ERL_NIF_TERM nif_regions(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int n, i;
    ERL_NIF_TERM list;
    (void)argc; (void)argv;

    n = pn_region_count();
    list = enif_make_list(env, 0);
    /* Build back-to-front so the result comes out in the engine's own order. */
    for (i = n - 1; i >= 0; i--) {
        ERL_NIF_TERM item = take_binary(env, pn_region_at(i));
        list = enif_make_list_cell(env, item, list);
    }
    return list;
}

/* ---- introspection ---- */

static ERL_NIF_TERM nif_abi_version(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    (void)argc; (void)argv;
    return enif_make_int(env, pn_abi_version());
}

/* ---- engine discovery + symbol resolution ----
 *
 * Order, matching every other binding in the monorepo:
 *   1. $LIBPHONENUMBER_AE_LIB
 *   2. priv/ next to this NIF (the bundled copy .build.ae stages)
 *   3. the OS loader's own search path
 *
 * We dlopen rather than link so the NIF .so has no DT_NEEDED on the engine:
 * the BEAM can load this module even when the engine is missing, and report a
 * clean load error instead of dying in the dynamic linker.
 */

#define RESOLVE(var, name)                                       \
    do {                                                         \
        *(void **)(&var) = PN_DLSYM(pn_lib, name);               \
        if (!var) {                                              \
            snprintf(errbuf, errlen, "missing symbol %s", name); \
            return 0;                                            \
        }                                                        \
    } while (0)

static int resolve_all(char *errbuf, size_t errlen)
{
    RESOLVE(pn_abi_version, "aether_pn_embed_abi_version");
    RESOLVE(pn_free_string, "aether_pn_embed_free_string");
    /* metadata */
    RESOLVE(pn_country_code, "aether_pn_embed_country_code");
    RESOLVE(pn_example_number, "aether_pn_embed_example_number");
    RESOLVE(pn_example_number_for_type, "aether_pn_embed_example_number_for_type");
    RESOLVE(pn_invalid_example_number, "aether_pn_embed_invalid_example_number");
    RESOLVE(pn_possible_lengths, "aether_pn_embed_possible_lengths");
    RESOLVE(pn_region_code_for_country_code, "aether_pn_embed_region_code_for_country_code");
    RESOLVE(pn_is_nanpa_country, "aether_pn_embed_is_nanpa_country");
    RESOLVE(pn_ndd_prefix_for_region, "aether_pn_embed_ndd_prefix_for_region");
    RESOLVE(pn_region_count, "aether_pn_embed_region_count");
    RESOLVE(pn_region_at, "aether_pn_embed_region_at");
    RESOLVE(pn_cc_region_count, "aether_pn_embed_cc_region_count");
    RESOLVE(pn_cc_region_at, "aether_pn_embed_cc_region_at");
    /* parse + accessors */
    RESOLVE(pn_parse, "aether_pn_embed_parse");
    RESOLVE(pn_national_number, "aether_pn_embed_national_number");
    RESOLVE(pn_pn_region, "aether_pn_embed_pn_region");
    RESOLVE(pn_pn_country_code, "aether_pn_embed_pn_country_code");
    RESOLVE(pn_pn_national_number, "aether_pn_embed_pn_national_number");
    RESOLVE(pn_pn_extension, "aether_pn_embed_pn_extension");
    RESOLVE(pn_pn_italian_leading_zero, "aether_pn_embed_pn_italian_leading_zero");
    RESOLVE(pn_pn_source, "aether_pn_embed_pn_source");
    RESOLVE(pn_pn_error, "aether_pn_embed_pn_error");
    RESOLVE(pn_region_code_for_number, "aether_pn_embed_region_code_for_number");
    RESOLVE(pn_national_significant_number, "aether_pn_embed_national_significant_number");
    RESOLVE(pn_length_of_ndc, "aether_pn_embed_length_of_ndc");
    RESOLVE(pn_length_of_area_code, "aether_pn_embed_length_of_area_code");
    RESOLVE(pn_is_geographical, "aether_pn_embed_is_geographical");
    /* validation */
    RESOLVE(pn_is_possible_number, "aether_pn_embed_is_possible_number");
    RESOLVE(pn_is_possible_number_with_reason, "aether_pn_embed_is_possible_number_with_reason");
    RESOLVE(pn_is_valid_number, "aether_pn_embed_is_valid_number");
    RESOLVE(pn_is_valid_number_for_region, "aether_pn_embed_is_valid_number_for_region");
    RESOLVE(pn_number_type, "aether_pn_embed_number_type");
    RESOLVE(pn_can_be_internationally_dialled, "aether_pn_embed_can_be_internationally_dialled");
    /* formatting */
    RESOLVE(pn_format, "aether_pn_embed_format");
    RESOLVE(pn_format_out_of_country, "aether_pn_embed_format_out_of_country");
    RESOLVE(pn_format_in_original, "aether_pn_embed_format_in_original");
    /* relations / helpers */
    RESOLVE(pn_is_number_match, "aether_pn_embed_is_number_match");
    RESOLVE(pn_truncate_too_long, "aether_pn_embed_truncate_too_long");
    RESOLVE(pn_normalize_digits_only, "aether_pn_embed_normalize_digits_only");
    RESOLVE(pn_convert_alpha_characters, "aether_pn_embed_convert_alpha_characters");
    RESOLVE(pn_is_alpha_number, "aether_pn_embed_is_alpha_number");
    /* AsYouType */
    RESOLVE(pn_ayt_new, "aether_pn_embed_ayt_new");
    RESOLVE(pn_ayt_input, "aether_pn_embed_ayt_input");
    RESOLVE(pn_ayt_result, "aether_pn_embed_ayt_result");
    RESOLVE(pn_ayt_clear, "aether_pn_embed_ayt_clear");
    /* matcher */
    RESOLVE(pn_matcher_count, "aether_pn_embed_matcher_count");
    RESOLVE(pn_matcher_start, "aether_pn_embed_matcher_start");
    RESOLVE(pn_matcher_end, "aether_pn_embed_matcher_end");
    RESOLVE(pn_matcher_raw, "aether_pn_embed_matcher_raw");
    /* ShortNumberInfo */
    RESOLVE(pn_short_is_possible, "aether_pn_embed_short_is_possible");
    RESOLVE(pn_short_is_valid, "aether_pn_embed_short_is_valid");
    RESOLVE(pn_short_is_emergency, "aether_pn_embed_short_is_emergency");
    RESOLVE(pn_short_connects_to_emergency, "aether_pn_embed_short_connects_to_emergency");
    RESOLVE(pn_short_is_carrier_specific, "aether_pn_embed_short_is_carrier_specific");
    RESOLVE(pn_short_is_sms_service, "aether_pn_embed_short_is_sms_service");
    RESOLVE(pn_short_expected_cost, "aether_pn_embed_short_expected_cost");
    RESOLVE(pn_short_example_number, "aether_pn_embed_short_example_number");
    /* PhoneNumberToTimeZonesMapper */
    RESOLVE(pn_tz_count, "aether_pn_embed_tz_count");
    RESOLVE(pn_tz_at, "aether_pn_embed_tz_at");
    RESOLVE(pn_tz_all, "aether_pn_embed_tz_all");
    RESOLVE(pn_tz_unknown, "aether_pn_embed_tz_unknown");
    /* PhoneNumberToCarrierMapper */
    RESOLVE(pn_carrier_name, "aether_pn_embed_carrier_name");
    RESOLVE(pn_carrier_name_for_valid, "aether_pn_embed_carrier_name_for_valid");
    /* PhoneNumberOfflineGeocoder */
    RESOLVE(pn_geo_description, "aether_pn_embed_geo_description");
    RESOLVE(pn_geo_description_for_valid, "aether_pn_embed_geo_description_for_valid");
    return 1;
}

/* Where is this NIF's priv/ directory? The load info term carries it (see
 * phonenumber_ae_nif.erl), which is more reliable than guessing from
 * code:priv_dir inside C. */
static int open_engine(ErlNifEnv *env, ERL_NIF_TERM load_info, char *errbuf, size_t errlen)
{
    char path[4096];
    const char *env_path = getenv("LIBPHONENUMBER_AE_LIB");

    if (env_path && *env_path) {
        pn_lib = PN_DLOPEN(env_path);
        if (pn_lib) return 1;
    }

    /* load_info is the priv dir as a binary, or the atom 'undefined'. */
    {
        ErlNifBinary bin;
        if (enif_inspect_binary(env, load_info, &bin) && bin.size > 0 &&
            bin.size + 1 + sizeof(PN_LIB_NAME) < sizeof(path)) {
            memcpy(path, bin.data, bin.size);
            path[bin.size] = '\0';
            strcat(path, "/");
            strcat(path, PN_LIB_NAME);
            pn_lib = PN_DLOPEN(path);
            if (pn_lib) return 1;
        }
    }

    /* Let the OS loader try its own search path (LD_LIBRARY_PATH, rpath, …). */
    pn_lib = PN_DLOPEN(PN_LIB_NAME);
    if (pn_lib) return 1;

    snprintf(errbuf, errlen,
             "could not load %s. Set LIBPHONENUMBER_AE_LIB to its absolute path.",
             PN_LIB_NAME);
    return 0;
}

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info)
{
    char errbuf[512];
    (void)priv_data;

    errbuf[0] = '\0';

    if (!open_engine(env, load_info, errbuf, sizeof(errbuf))) {
        enif_fprintf(stderr, "phonenumber_ae_nif: %s\n", errbuf);
        return 2;
    }
    if (!resolve_all(errbuf, sizeof(errbuf))) {
        enif_fprintf(stderr, "phonenumber_ae_nif: %s\n", errbuf);
        return 3;
    }
    return 0;
}

/* An upgrade re-runs load's work in the new instance. */
static int upgrade(ErlNifEnv *env, void **priv_data, void **old_priv_data,
                   ERL_NIF_TERM load_info)
{
    (void)old_priv_data;
    return load(env, priv_data, load_info);
}

static ErlNifFunc nif_funcs[] = {
    /* metadata */
    {"country_code",                  1, nif_country_code,                  0},
    {"example_number",                1, nif_example_number,                0},
    {"example_number_for_type",       2, nif_example_number_for_type,       0},
    {"invalid_example_number",        1, nif_invalid_example_number,        0},
    {"possible_lengths",              1, nif_possible_lengths,              0},
    {"region_code_for_country_code",  1, nif_region_code_for_country_code,  0},
    {"is_nanpa_country",              1, nif_is_nanpa_country,              0},
    {"ndd_prefix_for_region",         2, nif_ndd_prefix_for_region,         0},
    {"region_count",                  0, nif_region_count,                  0},
    {"region_at",                     1, nif_region_at,                     0},
    {"regions",                       0, nif_regions,                       0},
    {"cc_region_count",               1, nif_cc_region_count,               0},
    {"cc_region_at",                  2, nif_cc_region_at,                  0},
    /* parse + accessors */
    {"parse",                         2, nif_parse,                         0},
    {"national_number",               2, nif_national_number,               0},
    {"pn_region",                     1, nif_pn_region,                     0},
    {"pn_country_code",               1, nif_pn_country_code,               0},
    {"pn_national_number",            1, nif_pn_national_number,            0},
    {"pn_extension",                  1, nif_pn_extension,                  0},
    {"pn_italian_leading_zero",       1, nif_pn_italian_leading_zero,       0},
    {"pn_source",                     1, nif_pn_source,                     0},
    {"pn_error",                      1, nif_pn_error,                      0},
    {"region_code_for_number",        1, nif_region_code_for_number,        0},
    {"national_significant_number",   1, nif_national_significant_number,   0},
    {"length_of_ndc",                 1, nif_length_of_ndc,                 0},
    {"length_of_area_code",           1, nif_length_of_area_code,           0},
    {"is_geographical",               1, nif_is_geographical,               0},
    /* validation */
    {"is_possible_number",            2, nif_is_possible_number,            0},
    {"is_possible_number_with_reason",2, nif_is_possible_number_with_reason,0},
    {"is_valid_number",               2, nif_is_valid_number,               0},
    {"is_valid_number_for_region",    2, nif_is_valid_number_for_region,    0},
    {"number_type",                   2, nif_number_type,                   0},
    {"can_be_internationally_dialled",2, nif_can_be_internationally_dialled,0},
    /* formatting */
    {"format",                        3, nif_format,                        0},
    {"format_out_of_country",         3, nif_format_out_of_country,         0},
    {"format_in_original",            2, nif_format_in_original,            0},
    /* relations / helpers */
    {"is_number_match",               2, nif_is_number_match,               0},
    {"truncate_too_long",             2, nif_truncate_too_long,             0},
    {"normalize_digits_only",         1, nif_normalize_digits_only,         0},
    {"convert_alpha_characters",      1, nif_convert_alpha_characters,      0},
    {"is_alpha_number",               1, nif_is_alpha_number,               0},
    /* AsYouType */
    {"ayt_new",                       1, nif_ayt_new,                       0},
    {"ayt_input",                     2, nif_ayt_input,                     0},
    {"ayt_result",                    1, nif_ayt_result,                    0},
    {"ayt_clear",                     1, nif_ayt_clear,                     0},
    /* matcher */
    {"matcher_count",                 3, nif_matcher_count,                 0},
    {"matcher_start",                 4, nif_matcher_start,                 0},
    {"matcher_end",                   4, nif_matcher_end,                   0},
    {"matcher_raw",                   4, nif_matcher_raw,                   0},
    /* ShortNumberInfo */
    {"short_is_possible",             2, nif_short_is_possible,             0},
    {"short_is_valid",                2, nif_short_is_valid,                0},
    {"short_is_emergency",            2, nif_short_is_emergency,            0},
    {"short_connects_to_emergency",   2, nif_short_connects_to_emergency,   0},
    {"short_is_carrier_specific",     2, nif_short_is_carrier_specific,     0},
    {"short_is_sms_service",          2, nif_short_is_sms_service,          0},
    {"short_expected_cost",           2, nif_short_expected_cost,           0},
    {"short_example_number",          1, nif_short_example_number,          0},
    /* PhoneNumberToTimeZonesMapper */
    {"tz_count",                      2, nif_tz_count,                      0},
    {"tz_at",                         3, nif_tz_at,                         0},
    {"tz_all",                        2, nif_tz_all,                        0},
    {"tz_unknown",                    0, nif_tz_unknown,                    0},
    /* PhoneNumberToCarrierMapper (v7: region, input, lang) */
    {"carrier_name",                  3, nif_carrier_name,                  0},
    {"carrier_name_for_valid",        3, nif_carrier_name_for_valid,        0},
    /* PhoneNumberOfflineGeocoder (v7: region, input, lang) */
    {"geo_description",               3, nif_geo_description,               0},
    {"geo_description_for_valid",     3, nif_geo_description_for_valid,     0},
    /* introspection */
    {"abi_version",                   0, nif_abi_version,                   0}
};

ERL_NIF_INIT(phonenumber_ae_nif, nif_funcs, load, NULL, upgrade, NULL)
