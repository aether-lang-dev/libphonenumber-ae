/* lua/src/phonenumber_ae.c — the Lua 5.4 C extension over the phonenumber
 * C ABI (core/embed.ae), ABI v2.
 *
 * This file is the ONLY place in the Lua binding that knows about the C ABI.
 * Everything above it (lua/src/phonenumber_ae.lua) is idiomatic Lua over these
 * functions. No phone-number logic lives here or anywhere else in this binding
 * — the engine is core/phonenumber.ae, shared by every language binding.
 *
 * Lua has no FFI in its standard distribution (LuaJIT's `ffi` is not Lua 5.4),
 * so unlike the ctypes/Fiddle/koffi bindings this one is a real C extension. It
 * still `dlopen`s the engine rather than linking it, so the same
 * LIBPHONENUMBER_AE_LIB resolution order as every other binding applies and one
 * .so serves them all.
 *
 * v2 is full PhoneNumberUtil parity: 50 ABI symbols. Signatures are still
 * scalar-only (const char* / int). There are still no opaque handles — a parsed
 * number and an AsYouType state are themselves caller-owned STRINGS that come
 * back from the engine, get passed to accessor calls, and are freed like any
 * other returned string. So there is still no per-object userdata here: the
 * idiomatic ParsedNumber / AsYouTypeFormatter objects live in the Lua layer and
 * simply hold that string.
 *
 * Build:
 *   cc -O2 -fPIC -shared -I/usr/include/lua5.4 \
 *      src/phonenumber_ae.c -o phonenumber_ae_native.so -ldl
 *
 * ## Naming
 *
 * core/embed.ae names its exports pn_embed_<name>; building with --emit=lib
 * mangles them to aether_pn_embed_<name>. That mangled name is what we dlsym.
 *
 * ## The one ownership rule
 *
 * Every char* the ABI returns is caller-owned and must go back to
 * aether_pn_embed_free_string. push_owned() below is the only place a returned
 * string is turned into a Lua string, and it always frees.
 */

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>

/* ---- the ABI, dlsym'd once ---- */

typedef int   (*fn_int_void)(void);
typedef void  (*fn_free_string)(char*);
typedef char* (*fn_str_str)(const char*);
typedef char* (*fn_str_str2)(const char*, const char*);
typedef char* (*fn_str_str3)(const char*, const char*, const char*);
typedef int   (*fn_int_str)(const char*);
typedef int   (*fn_int_str2)(const char*, const char*);
typedef char* (*fn_str_str_int)(const char*, const char*, int);
typedef char* (*fn_str_str_i)(const char*, int);
typedef char* (*fn_str_int)(int);
typedef int   (*fn_int_str_int)(const char*, int);
typedef int   (*fn_matcher_int)(const char*, const char*, int, int);
typedef char* (*fn_matcher_str)(const char*, const char*, int, int);
typedef int   (*fn_count3)(const char*, const char*, int);

typedef struct {
    void* handle;                     /* the dlopen'd engine */
    char  path[4096];                 /* where it came from */

    fn_int_void    abi_version;
    fn_free_string free_string;
    /* metadata */
    fn_str_str     country_code;
    fn_str_str     example_number;
    fn_str_str_i   example_number_for_type;
    fn_str_str     invalid_example_number;
    fn_str_str     possible_lengths;
    fn_str_str     region_code_for_country_code;
    fn_int_str     is_nanpa_country;
    fn_str_str_i   ndd_prefix_for_region;
    fn_int_void    region_count;
    fn_str_int     region_at;
    fn_int_str     cc_region_count;
    fn_str_str_i   cc_region_at;
    /* parse + accessors */
    fn_str_str2    parse;
    fn_str_str2    national_number;
    fn_str_str     pn_region;
    fn_str_str     pn_country_code;
    fn_str_str     pn_national_number;
    fn_str_str     pn_extension;
    fn_int_str     pn_italian_leading_zero;
    fn_int_str     pn_source;
    fn_str_str     pn_error;
    fn_str_str     region_code_for_number;
    fn_str_str     national_significant_number;
    fn_int_str     length_of_ndc;
    fn_int_str     length_of_area_code;
    fn_int_str     is_geographical;
    /* validation */
    fn_int_str2    is_possible_number;
    fn_int_str2    is_possible_number_with_reason;
    fn_int_str2    is_valid_number;
    fn_int_str2    is_valid_number_for_region;
    fn_int_str2    number_type;
    fn_int_str2    can_be_internationally_dialled;
    /* formatting */
    fn_str_str_int format;
    fn_str_str3    format_out_of_country;
    fn_str_str2    format_in_original;
    /* relations / helpers */
    fn_int_str2    is_number_match;
    fn_str_str2    truncate_too_long;
    fn_str_str     normalize_digits_only;
    fn_str_str     convert_alpha_characters;
    fn_int_str     is_alpha_number;
    /* AsYouType */
    fn_str_str     ayt_new;
    fn_str_str2    ayt_input;
    fn_str_str     ayt_result;
    fn_str_str     ayt_clear;
    /* matcher */
    fn_count3      matcher_count;
    fn_matcher_int matcher_start;
    fn_matcher_int matcher_end;
    fn_matcher_str matcher_raw;
} Engine;

static Engine ENGINE;                 /* process-wide; loaded once */

/* ---- engine loading ---- */

static int load_symbols(lua_State* L, void* lib, const char* path) {
#define SYM(field, name)                                                   \
    do {                                                                   \
        *(void**)(&ENGINE.field) = dlsym(lib, name);                       \
        if (!ENGINE.field) {                                               \
            dlclose(lib);                                                  \
            memset(&ENGINE, 0, sizeof(ENGINE));                            \
            return luaL_error(L, "phonenumber_ae: engine at '%s' is missing "\
                                 "symbol %s", path, name);                 \
        }                                                                  \
    } while (0)

    SYM(abi_version,                    "aether_pn_embed_abi_version");
    SYM(free_string,                    "aether_pn_embed_free_string");
    /* metadata */
    SYM(country_code,                   "aether_pn_embed_country_code");
    SYM(example_number,                 "aether_pn_embed_example_number");
    SYM(example_number_for_type,        "aether_pn_embed_example_number_for_type");
    SYM(invalid_example_number,         "aether_pn_embed_invalid_example_number");
    SYM(possible_lengths,               "aether_pn_embed_possible_lengths");
    SYM(region_code_for_country_code,   "aether_pn_embed_region_code_for_country_code");
    SYM(is_nanpa_country,               "aether_pn_embed_is_nanpa_country");
    SYM(ndd_prefix_for_region,          "aether_pn_embed_ndd_prefix_for_region");
    SYM(region_count,                   "aether_pn_embed_region_count");
    SYM(region_at,                      "aether_pn_embed_region_at");
    SYM(cc_region_count,                "aether_pn_embed_cc_region_count");
    SYM(cc_region_at,                   "aether_pn_embed_cc_region_at");
    /* parse + accessors */
    SYM(parse,                          "aether_pn_embed_parse");
    SYM(national_number,                "aether_pn_embed_national_number");
    SYM(pn_region,                      "aether_pn_embed_pn_region");
    SYM(pn_country_code,                "aether_pn_embed_pn_country_code");
    SYM(pn_national_number,             "aether_pn_embed_pn_national_number");
    SYM(pn_extension,                   "aether_pn_embed_pn_extension");
    SYM(pn_italian_leading_zero,        "aether_pn_embed_pn_italian_leading_zero");
    SYM(pn_source,                      "aether_pn_embed_pn_source");
    SYM(pn_error,                       "aether_pn_embed_pn_error");
    SYM(region_code_for_number,         "aether_pn_embed_region_code_for_number");
    SYM(national_significant_number,    "aether_pn_embed_national_significant_number");
    SYM(length_of_ndc,                  "aether_pn_embed_length_of_ndc");
    SYM(length_of_area_code,            "aether_pn_embed_length_of_area_code");
    SYM(is_geographical,                "aether_pn_embed_is_geographical");
    /* validation */
    SYM(is_possible_number,             "aether_pn_embed_is_possible_number");
    SYM(is_possible_number_with_reason, "aether_pn_embed_is_possible_number_with_reason");
    SYM(is_valid_number,                "aether_pn_embed_is_valid_number");
    SYM(is_valid_number_for_region,     "aether_pn_embed_is_valid_number_for_region");
    SYM(number_type,                    "aether_pn_embed_number_type");
    SYM(can_be_internationally_dialled, "aether_pn_embed_can_be_internationally_dialled");
    /* formatting */
    SYM(format,                         "aether_pn_embed_format");
    SYM(format_out_of_country,          "aether_pn_embed_format_out_of_country");
    SYM(format_in_original,             "aether_pn_embed_format_in_original");
    /* relations / helpers */
    SYM(is_number_match,                "aether_pn_embed_is_number_match");
    SYM(truncate_too_long,              "aether_pn_embed_truncate_too_long");
    SYM(normalize_digits_only,          "aether_pn_embed_normalize_digits_only");
    SYM(convert_alpha_characters,       "aether_pn_embed_convert_alpha_characters");
    SYM(is_alpha_number,                "aether_pn_embed_is_alpha_number");
    /* AsYouType */
    SYM(ayt_new,                        "aether_pn_embed_ayt_new");
    SYM(ayt_input,                      "aether_pn_embed_ayt_input");
    SYM(ayt_result,                     "aether_pn_embed_ayt_result");
    SYM(ayt_clear,                      "aether_pn_embed_ayt_clear");
    /* matcher */
    SYM(matcher_count,                  "aether_pn_embed_matcher_count");
    SYM(matcher_start,                  "aether_pn_embed_matcher_start");
    SYM(matcher_end,                    "aether_pn_embed_matcher_end");
    SYM(matcher_raw,                    "aether_pn_embed_matcher_raw");
#undef SYM

    ENGINE.handle = lib;
    snprintf(ENGINE.path, sizeof(ENGINE.path), "%s", path);
    return 0;
}

/* Candidates, in resolution order:
 *   1. an explicit path passed to load()
 *   2. $LIBPHONENUMBER_AE_LIB
 *   3. native/ next to this extension, then ../core/native/
 *   4. the OS loader's own search path
 */
static int engine_load(lua_State* L, const char* explicit_path) {
    if (ENGINE.handle && !explicit_path) return 0;

    const char* candidates[8];
    int n = 0;
    static const char* NAME = "libphonenumber_ae.so";

    if (explicit_path && *explicit_path) {
        candidates[n++] = explicit_path;
    } else {
        const char* env = getenv("LIBPHONENUMBER_AE_LIB");
        if (env && *env) candidates[n++] = env;
        candidates[n++] = "native/libphonenumber_ae.so";
        candidates[n++] = "../core/native/libphonenumber_ae.so";
        candidates[n++] = NAME;
    }

    const char* last_err = "(none)";
    for (int i = 0; i < n; i++) {
        void* lib = dlopen(candidates[i], RTLD_NOW | RTLD_LOCAL);
        if (lib) return load_symbols(L, lib, candidates[i]);
        const char* e = dlerror();
        if (e) last_err = e;
    }
    return luaL_error(L,
        "phonenumber_ae: could not load the engine (%s). Set "
        "LIBPHONENUMBER_AE_LIB to its absolute path, or build it with:\n"
        "  aeb core/.build.ae\nLast dlerror: %s", NAME, last_err);
}

/* ---- string helper ---- */

/* Push an ABI-returned string and FREE it. Every char* out of the engine is
 * caller-owned; this is the single place that ownership is discharged. */
static void push_owned(lua_State* L, char* s) {
    if (!s) { lua_pushliteral(L, ""); return; }
    lua_pushstring(L, s);
    ENGINE.free_string(s);
}

/* ---- metadata ---- */

static int l_abi_version(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.abi_version());
    return 1;
}

static int l_engine_path(lua_State* L) {
    engine_load(L, NULL);
    lua_pushstring(L, ENGINE.path);
    return 1;
}

/* The optional first argument to load() is an explicit engine path. It is only
 * honored the first time (before the process-wide handle is set). */
static int l_load(lua_State* L) {
    const char* path = luaL_optstring(L, 1, NULL);
    engine_load(L, path);
    lua_pushstring(L, ENGINE.path);
    return 1;
}

static int l_country_code(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.country_code(luaL_checkstring(L, 1)));
    return 1;
}

static int l_example_number(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.example_number(luaL_checkstring(L, 1)));
    return 1;
}

static int l_example_number_for_type(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.example_number_for_type(luaL_checkstring(L, 1),
                                                 (int)luaL_checkinteger(L, 2)));
    return 1;
}

static int l_invalid_example_number(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.invalid_example_number(luaL_checkstring(L, 1)));
    return 1;
}

static int l_possible_lengths(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.possible_lengths(luaL_checkstring(L, 1)));
    return 1;
}

static int l_region_code_for_country_code(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.region_code_for_country_code(luaL_checkstring(L, 1)));
    return 1;
}

static int l_is_nanpa_country(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.is_nanpa_country(luaL_checkstring(L, 1)));
    return 1;
}

static int l_ndd_prefix_for_region(lua_State* L) {
    engine_load(L, NULL);
    /* strip_non_digits crosses as 0/1; the Lua layer maps a boolean to it. */
    int strip = lua_toboolean(L, 2);
    push_owned(L, ENGINE.ndd_prefix_for_region(luaL_checkstring(L, 1), strip));
    return 1;
}

static int l_region_count(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.region_count());
    return 1;
}

static int l_region_at(lua_State* L) {
    engine_load(L, NULL);
    /* Lua is 1-based; the ABI is 0-based. The conversion lives here so the Lua
     * surface above never sees a 0-based index. */
    lua_Integer i = luaL_checkinteger(L, 1);
    push_owned(L, ENGINE.region_at((int)(i - 1)));
    return 1;
}

static int l_cc_region_count(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.cc_region_count(luaL_checkstring(L, 1)));
    return 1;
}

static int l_cc_region_at(lua_State* L) {
    engine_load(L, NULL);
    /* 1-based index in; ABI is 0-based. */
    lua_Integer i = luaL_checkinteger(L, 2);
    push_owned(L, ENGINE.cc_region_at(luaL_checkstring(L, 1), (int)(i - 1)));
    return 1;
}

/* ---- parse + accessors ---- */
/* parse() and the pn_* accessors all traffic in the caller-owned parsed-number
 * STRING. The Lua layer keeps that string inside a ParsedNumber table and hands
 * it back to each accessor. */

static int l_parse(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.parse(luaL_checkstring(L, 1), luaL_checkstring(L, 2)));
    return 1;
}

static int l_national_number(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.national_number(luaL_checkstring(L, 1),
                                         luaL_checkstring(L, 2)));
    return 1;
}

static int l_pn_region(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.pn_region(luaL_checkstring(L, 1)));
    return 1;
}

static int l_pn_country_code(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.pn_country_code(luaL_checkstring(L, 1)));
    return 1;
}

static int l_pn_national_number(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.pn_national_number(luaL_checkstring(L, 1)));
    return 1;
}

static int l_pn_extension(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.pn_extension(luaL_checkstring(L, 1)));
    return 1;
}

static int l_pn_italian_leading_zero(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.pn_italian_leading_zero(luaL_checkstring(L, 1)));
    return 1;
}

static int l_pn_source(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.pn_source(luaL_checkstring(L, 1)));
    return 1;
}

static int l_pn_error(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.pn_error(luaL_checkstring(L, 1)));
    return 1;
}

static int l_region_code_for_number(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.region_code_for_number(luaL_checkstring(L, 1)));
    return 1;
}

static int l_national_significant_number(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.national_significant_number(luaL_checkstring(L, 1)));
    return 1;
}

static int l_length_of_ndc(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.length_of_ndc(luaL_checkstring(L, 1)));
    return 1;
}

static int l_length_of_area_code(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.length_of_area_code(luaL_checkstring(L, 1)));
    return 1;
}

static int l_is_geographical(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.is_geographical(luaL_checkstring(L, 1)));
    return 1;
}

/* ---- validation ---- */

static int l_is_possible_number(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.is_possible_number(luaL_checkstring(L, 1),
                                                 luaL_checkstring(L, 2)));
    return 1;
}

static int l_is_possible_number_with_reason(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.is_possible_number_with_reason(
                           luaL_checkstring(L, 1), luaL_checkstring(L, 2)));
    return 1;
}

static int l_is_valid_number(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.is_valid_number(luaL_checkstring(L, 1),
                                              luaL_checkstring(L, 2)));
    return 1;
}

static int l_is_valid_number_for_region(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.is_valid_number_for_region(
                           luaL_checkstring(L, 1), luaL_checkstring(L, 2)));
    return 1;
}

static int l_number_type(lua_State* L) {
    engine_load(L, NULL);
    /* The result is a plain int, -1..9. It crosses as a Lua integer; the
     * idiomatic layer maps it to a TYPE_* name. */
    lua_pushinteger(L, ENGINE.number_type(luaL_checkstring(L, 1),
                                          luaL_checkstring(L, 2)));
    return 1;
}

static int l_can_be_internationally_dialled(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.can_be_internationally_dialled(
                           luaL_checkstring(L, 1), luaL_checkstring(L, 2)));
    return 1;
}

/* ---- formatting ---- */

static int l_format(lua_State* L) {
    engine_load(L, NULL);
    /* fmt is 0 E164, 1 INTERNATIONAL, 2 NATIONAL, 3 RFC3966 — crosses as C int. */
    int fmt = (int)luaL_checkinteger(L, 3);
    push_owned(L, ENGINE.format(luaL_checkstring(L, 1),
                                luaL_checkstring(L, 2), fmt));
    return 1;
}

static int l_format_out_of_country(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.format_out_of_country(luaL_checkstring(L, 1),
                                               luaL_checkstring(L, 2),
                                               luaL_checkstring(L, 3)));
    return 1;
}

static int l_format_in_original(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.format_in_original(luaL_checkstring(L, 1),
                                            luaL_checkstring(L, 2)));
    return 1;
}

/* ---- relations / helpers ---- */

static int l_is_number_match(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.is_number_match(luaL_checkstring(L, 1),
                                              luaL_checkstring(L, 2)));
    return 1;
}

static int l_truncate_too_long(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.truncate_too_long(luaL_checkstring(L, 1),
                                           luaL_checkstring(L, 2)));
    return 1;
}

static int l_normalize_digits_only(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.normalize_digits_only(luaL_checkstring(L, 1)));
    return 1;
}

static int l_convert_alpha_characters(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.convert_alpha_characters(luaL_checkstring(L, 1)));
    return 1;
}

static int l_is_alpha_number(lua_State* L) {
    engine_load(L, NULL);
    lua_pushboolean(L, ENGINE.is_alpha_number(luaL_checkstring(L, 1)));
    return 1;
}

/* ---- AsYouTypeFormatter (state threaded as a caller-owned string) ---- */

static int l_ayt_new(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.ayt_new(luaL_checkstring(L, 1)));
    return 1;
}

static int l_ayt_input(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.ayt_input(luaL_checkstring(L, 1),
                                   luaL_checkstring(L, 2)));
    return 1;
}

static int l_ayt_result(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.ayt_result(luaL_checkstring(L, 1)));
    return 1;
}

static int l_ayt_clear(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.ayt_clear(luaL_checkstring(L, 1)));
    return 1;
}

/* ---- PhoneNumberMatcher / findNumbers ---- */

static int l_matcher_count(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.matcher_count(luaL_checkstring(L, 1),
                                            luaL_checkstring(L, 2),
                                            (int)luaL_checkinteger(L, 3)));
    return 1;
}

static int l_matcher_start(lua_State* L) {
    engine_load(L, NULL);
    /* idx is 0-based at the ABI; the Lua layer passes it through as given. */
    lua_pushinteger(L, ENGINE.matcher_start(luaL_checkstring(L, 1),
                                            luaL_checkstring(L, 2),
                                            (int)luaL_checkinteger(L, 3),
                                            (int)luaL_checkinteger(L, 4)));
    return 1;
}

static int l_matcher_end(lua_State* L) {
    engine_load(L, NULL);
    lua_pushinteger(L, ENGINE.matcher_end(luaL_checkstring(L, 1),
                                          luaL_checkstring(L, 2),
                                          (int)luaL_checkinteger(L, 3),
                                          (int)luaL_checkinteger(L, 4)));
    return 1;
}

static int l_matcher_raw(lua_State* L) {
    engine_load(L, NULL);
    push_owned(L, ENGINE.matcher_raw(luaL_checkstring(L, 1),
                                     luaL_checkstring(L, 2),
                                     (int)luaL_checkinteger(L, 3),
                                     (int)luaL_checkinteger(L, 4)));
    return 1;
}

/* ---- module table ---- */

static const luaL_Reg MODULE[] = {
    {"load",                          l_load},
    {"engine_path",                   l_engine_path},
    {"abi_version",                   l_abi_version},
    /* metadata */
    {"country_code",                  l_country_code},
    {"example_number",                l_example_number},
    {"example_number_for_type",       l_example_number_for_type},
    {"invalid_example_number",        l_invalid_example_number},
    {"possible_lengths",              l_possible_lengths},
    {"region_code_for_country_code",  l_region_code_for_country_code},
    {"is_nanpa_country",              l_is_nanpa_country},
    {"ndd_prefix_for_region",         l_ndd_prefix_for_region},
    {"region_count",                  l_region_count},
    {"region_at",                     l_region_at},
    {"cc_region_count",               l_cc_region_count},
    {"cc_region_at",                  l_cc_region_at},
    /* parse + accessors */
    {"parse",                         l_parse},
    {"national_number",               l_national_number},
    {"pn_region",                     l_pn_region},
    {"pn_country_code",               l_pn_country_code},
    {"pn_national_number",            l_pn_national_number},
    {"pn_extension",                  l_pn_extension},
    {"pn_italian_leading_zero",       l_pn_italian_leading_zero},
    {"pn_source",                     l_pn_source},
    {"pn_error",                      l_pn_error},
    {"region_code_for_number",        l_region_code_for_number},
    {"national_significant_number",   l_national_significant_number},
    {"length_of_ndc",                 l_length_of_ndc},
    {"length_of_area_code",           l_length_of_area_code},
    {"is_geographical",               l_is_geographical},
    /* validation */
    {"is_possible_number",            l_is_possible_number},
    {"is_possible_number_with_reason", l_is_possible_number_with_reason},
    {"is_valid_number",               l_is_valid_number},
    {"is_valid_number_for_region",    l_is_valid_number_for_region},
    {"number_type",                   l_number_type},
    {"can_be_internationally_dialled", l_can_be_internationally_dialled},
    /* formatting */
    {"format",                        l_format},
    {"format_out_of_country",         l_format_out_of_country},
    {"format_in_original",            l_format_in_original},
    /* relations / helpers */
    {"is_number_match",               l_is_number_match},
    {"truncate_too_long",             l_truncate_too_long},
    {"normalize_digits_only",         l_normalize_digits_only},
    {"convert_alpha_characters",      l_convert_alpha_characters},
    {"is_alpha_number",               l_is_alpha_number},
    /* AsYouType */
    {"ayt_new",                       l_ayt_new},
    {"ayt_input",                     l_ayt_input},
    {"ayt_result",                    l_ayt_result},
    {"ayt_clear",                     l_ayt_clear},
    /* matcher */
    {"matcher_count",                 l_matcher_count},
    {"matcher_start",                 l_matcher_start},
    {"matcher_end",                   l_matcher_end},
    {"matcher_raw",                   l_matcher_raw},
    {NULL, NULL}
};

int luaopen_phonenumber_ae_native(lua_State* L) {
    luaL_newlib(L, MODULE);

    /* ABI constants — append only, never renumber. */
#define K(name, value) \
    do { lua_pushinteger(L, (value)); lua_setfield(L, -2, name); } while (0)

    /* Format style — E164 is 0 in v2 (was 2 in v1). */
    K("E164", 0);
    K("INTERNATIONAL", 1);
    K("NATIONAL", 2);
    K("RFC3966", 3);

    /* Number type. */
    K("TYPE_UNKNOWN", -1);
    K("TYPE_FIXED_LINE", 0);
    K("TYPE_MOBILE", 1);
    K("TYPE_TOLL_FREE", 2);
    K("TYPE_PREMIUM_RATE", 3);
    K("TYPE_SHARED_COST", 4);
    K("TYPE_VOIP", 5);
    K("TYPE_PERSONAL_NUMBER", 6);
    K("TYPE_PAGER", 7);
    K("TYPE_UAN", 8);
    K("TYPE_VOICEMAIL", 9);

    /* ValidationResult (is_possible_number_with_reason). */
    K("VR_IS_POSSIBLE", 0);
    K("VR_IS_POSSIBLE_LOCAL_ONLY", 4);
    K("VR_INVALID_COUNTRY_CODE", 1);
    K("VR_TOO_SHORT", 2);
    K("VR_INVALID_LENGTH", 5);
    K("VR_TOO_LONG", 3);

    /* MatchType (is_number_match). */
    K("MATCH_NOT_A_NUMBER", 0);
    K("MATCH_NO_MATCH", 1);
    K("MATCH_SHORT_NSN", 2);
    K("MATCH_NSN", 3);
    K("MATCH_EXACT", 4);

    /* CountryCodeSource (pn_source). */
    K("SRC_FROM_NUMBER_WITH_PLUS", 1);
    K("SRC_FROM_NUMBER_WITH_IDD", 5);
    K("SRC_FROM_NUMBER_WITHOUT_PLUS", 10);
    K("SRC_FROM_DEFAULT_COUNTRY", 20);

    /* Matcher leniency. */
    K("LENIENCY_POSSIBLE", 0);
    K("LENIENCY_VALID", 1);
#undef K

    return 1;
}
