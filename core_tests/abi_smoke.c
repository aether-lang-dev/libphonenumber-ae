/* core_tests/abi_smoke.c — a complete consumer of the full phonenumber C ABI,
 * in C, using nothing but dlopen + dlsym. If this passes, a binding failure is a
 * binding bug, not an engine one.
 *
 * Build + run (the .abi.ae gate does this for you):
 *     cc -D_GNU_SOURCE -o abi_smoke core_tests/abi_smoke.c -ldl
 *     ./abi_smoke ./core/native/libphonenumber_ae.so
 *
 * Every char* the ABI returns is caller-owned; we free each through
 * aether_pn_embed_free_string. A parsed number and an AsYouType state are also
 * caller-owned strings threaded through the calls. Read alongside docs/abi.md.
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* format styles (match the engine's constants) */
#define FMT_E164 0
#define FMT_INTERNATIONAL 1
#define FMT_NATIONAL 2
#define FMT_RFC3966 3
/* number types */
#define TYPE_FIXED_LINE 0
#define TYPE_FIXED_LINE_OR_MOBILE 10
/* validation reasons */
#define VR_IS_POSSIBLE 0
#define VR_TOO_SHORT 2
#define VR_TOO_LONG 3
/* match types */
#define MATCH_NO_MATCH 1
#define MATCH_EXACT 4
/* country-code source */
#define SRC_FROM_NUMBER_WITH_PLUS 1
#define SRC_FROM_DEFAULT_COUNTRY 20

static int failures = 0;
static void *H;

static void *sym(const char *name) {
    void *p = dlsym(H, name);
    if (!p) { fprintf(stderr, "missing symbol: %s\n", name); exit(3); }
    return p;
}

/* the free function, resolved once */
static void (*free_string)(char *);

static void ck_i(const char *label, int got, int want) {
    if (got != want) { fprintf(stderr, "FAIL %s: got %d, want %d\n", label, got, want); failures++; }
}
/* compare an ABI-returned (caller-owned) string, then free it */
static void ck_s(const char *label, char *got, const char *want) {
    const char *g = got ? got : "";
    if (strcmp(g, want) != 0) { fprintf(stderr, "FAIL %s: got '%s', want '%s'\n", label, g, want); failures++; }
    if (got) free_string(got);
}

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "./core/native/libphonenumber_ae.so";
    H = dlopen(path, RTLD_NOW);
    if (!H) { fprintf(stderr, "dlopen failed: %s\n", dlerror()); return 2; }

    int   (*abi_version)(void)                                   = sym("aether_pn_embed_abi_version");
    free_string                                                  = sym("aether_pn_embed_free_string");
    char* (*country_code)(const char*)                           = sym("aether_pn_embed_country_code");
    char* (*example_number)(const char*)                         = sym("aether_pn_embed_example_number");
    char* (*possible_lengths)(const char*)                       = sym("aether_pn_embed_possible_lengths");
    char* (*rc_for_cc)(const char*)                              = sym("aether_pn_embed_region_code_for_country_code");
    int   (*is_nanpa)(const char*)                               = sym("aether_pn_embed_is_nanpa_country");
    int   (*region_count)(void)                                  = sym("aether_pn_embed_region_count");
    char* (*region_at)(int)                                      = sym("aether_pn_embed_region_at");
    int   (*cc_region_count)(const char*)                        = sym("aether_pn_embed_cc_region_count");
    char* (*cc_region_at)(const char*,int)                       = sym("aether_pn_embed_cc_region_at");
    char* (*parse)(const char*,const char*)                      = sym("aether_pn_embed_parse");
    char* (*pn_nn)(const char*)                                  = sym("aether_pn_embed_pn_national_number");
    char* (*pn_cc)(const char*)                                  = sym("aether_pn_embed_pn_country_code");
    char* (*pn_ext)(const char*)                                 = sym("aether_pn_embed_pn_extension");
    char* (*pn_err)(const char*)                                 = sym("aether_pn_embed_pn_error");
    int   (*pn_src)(const char*)                                 = sym("aether_pn_embed_pn_source");
    char* (*rc_for_number)(const char*)                          = sym("aether_pn_embed_region_code_for_number");
    char* (*nsn)(const char*)                                    = sym("aether_pn_embed_national_significant_number");
    int   (*len_ndc)(const char*)                                = sym("aether_pn_embed_length_of_ndc");
    int   (*is_possible)(const char*,const char*)                = sym("aether_pn_embed_is_possible_number");
    int   (*possible_reason)(const char*,const char*)            = sym("aether_pn_embed_is_possible_number_with_reason");
    int   (*is_valid)(const char*,const char*)                   = sym("aether_pn_embed_is_valid_number");
    int   (*is_valid_for_region)(const char*,const char*)        = sym("aether_pn_embed_is_valid_number_for_region");
    int   (*number_type)(const char*,const char*)                = sym("aether_pn_embed_number_type");
    char* (*format)(const char*,const char*,int)                 = sym("aether_pn_embed_format");
    char* (*format_ooc)(const char*,const char*,const char*)     = sym("aether_pn_embed_format_out_of_country");
    int   (*is_match)(const char*,const char*)                   = sym("aether_pn_embed_is_number_match");
    char* (*truncate)(const char*,const char*)                   = sym("aether_pn_embed_truncate_too_long");
    char* (*normalize)(const char*)                              = sym("aether_pn_embed_normalize_digits_only");
    char* (*conv_alpha)(const char*)                             = sym("aether_pn_embed_convert_alpha_characters");
    int   (*is_alpha)(const char*)                               = sym("aether_pn_embed_is_alpha_number");
    char* (*ayt_new)(const char*)                                = sym("aether_pn_embed_ayt_new");
    char* (*ayt_input)(const char*,const char*)                  = sym("aether_pn_embed_ayt_input");
    char* (*ayt_result)(const char*)                             = sym("aether_pn_embed_ayt_result");
    int   (*matcher_count)(const char*,const char*,int)          = sym("aether_pn_embed_matcher_count");
    char* (*matcher_raw)(const char*,const char*,int,int)        = sym("aether_pn_embed_matcher_raw");
    int   (*short_valid)(const char*,const char*)                = sym("aether_pn_embed_short_is_valid");
    int   (*short_emerg)(const char*,const char*)                = sym("aether_pn_embed_short_is_emergency");
    int   (*short_possible)(const char*,const char*)             = sym("aether_pn_embed_short_is_possible");
    int   (*short_cost)(const char*,const char*)                 = sym("aether_pn_embed_short_expected_cost");
    char* (*short_example)(const char*)                          = sym("aether_pn_embed_short_example_number");

    /* ABI version */
    ck_i("abi_version", abi_version(), 3);

    /* metadata plumbing */
    ck_s("US cc", country_code("US"), "1");
    ck_s("GB cc", country_code("GB"), "44");
    ck_s("unknown cc", country_code("ZZ"), "");
    ck_s("US example", example_number("US"), "2015550123");
    ck_s("US lengths", possible_lengths("US"), "10");
    ck_s("cc44 main region", rc_for_cc("44"), "GB");
    ck_i("US is NANPA", is_nanpa("US"), 1);

    /* region enumeration */
    int rc = region_count();
    if (rc < 200) { fprintf(stderr, "FAIL region_count: %d < 200\n", rc); failures++; }
    { char *r0 = region_at(0); if (!r0 || strlen(r0) != 2) { fprintf(stderr, "FAIL region_at(0)\n"); failures++; } if (r0) free_string(r0); }
    if (cc_region_count("1") < 2) { fprintf(stderr, "FAIL cc_region_count(1)\n"); failures++; }
    ck_s("cc1 region 0", cc_region_at("1", 0), "US");

    /* parse: +cc with extension */
    {
        char *p = parse("+1 201 555 0123 ext 42", "US");
        ck_s("parse err", pn_err(p), "");
        ck_s("parse cc", pn_cc(p), "1");
        ck_s("parse nn", pn_nn(p), "2015550123");
        ck_s("parse ext", pn_ext(p), "42");
        ck_i("parse source", pn_src(p), SRC_FROM_NUMBER_WITH_PLUS);
        ck_s("region for number", rc_for_number(p), "US");
        ck_s("nsn", nsn(p), "2015550123");
        ck_i("ndc length", len_ndc(p), 3);
        free_string(p);
    }
    /* parse: national with trunk prefix (GB 0) */
    {
        char *p = parse("01212345678", "GB");
        ck_s("GB strip trunk", pn_nn(p), "1212345678");
        ck_i("GB source default", pn_src(p), SRC_FROM_DEFAULT_COUNTRY);
        free_string(p);
    }

    /* validation + reasons */
    ck_i("US possible", is_possible("US", "2015550123"), 1);
    ck_i("US too short", possible_reason("US", "201555"), VR_TOO_SHORT);
    ck_i("US too long", possible_reason("US", "20155501234567"), VR_TOO_LONG);
    ck_i("US possible reason", possible_reason("US", "2015550123"), VR_IS_POSSIBLE);
    ck_i("US valid", is_valid("US", "2015550123"), 1);
    ck_i("US invalid shape", is_valid("US", "1015550123"), 0);
    ck_i("US valid +1", is_valid("US", "+12015550123"), 1);
    ck_i("US valid for region", is_valid_for_region("2015550123", "US"), 1);
    ck_i("US fixed-line-or-mobile type", number_type("US", "2015550123"), TYPE_FIXED_LINE_OR_MOBILE);
    ck_i("GB fixed-line type", number_type("GB", "2070313000"), TYPE_FIXED_LINE);

    /* formatting */
    ck_s("US national", format("US", "2015550123", FMT_NATIONAL), "(201) 555-0123");
    ck_s("US e164", format("US", "2015550123", FMT_E164), "+12015550123");
    ck_s("US intl", format("US", "2015550123", FMT_INTERNATIONAL), "+1 201-555-0123");
    ck_s("US rfc3966", format("US", "2015550123", FMT_RFC3966), "tel:+1-201-555-0123");
    /* out-of-country: from GB, US number dials 011 1 ... */
    { char *f = format_ooc("US", "2015550123", "GB"); if (!f || strncmp(f, "00", 2) != 0) { fprintf(stderr, "FAIL ooc: '%s'\n", f?f:""); failures++; } if (f) free_string(f); }

    /* relations / helpers */
    ck_i("match exact", is_match("+1 201 555 0123", "+12015550123"), MATCH_EXACT);
    ck_i("match no", is_match("+1 201 555 0123", "+1 202 555 0199"), MATCH_NO_MATCH);
    ck_s("truncate", truncate("US", "20155501239999"), "2015550123");
    ck_s("normalize", normalize("+1 (201) 555.0123"), "12015550123");
    ck_s("alpha convert", conv_alpha("1-800-FLOWERS"), "1-800-3569377");
    ck_i("is alpha", is_alpha("1-800-FLOWERS"), 1);

    /* AsYouTypeFormatter */
    {
        char *s = ayt_new("US");
        const char *seq = "2015550123";
        for (int i = 0; seq[i]; i++) {
            char ch[2] = { seq[i], 0 };
            char *s2 = ayt_input(s, ch);
            free_string(s);
            s = s2;
        }
        ck_s("ayt result", ayt_result(s), "(201) 555-0123");
        free_string(s);
    }

    /* matcher */
    ck_i("matcher count", matcher_count("call 201-555-0123 or +1 202 555 0199", "US", 1), 2);
    ck_s("matcher raw 0", matcher_raw("call 201-555-0123 now", "US", 1, 0), "201-555-0123");


    /* ShortNumberInfo */
    ck_i("US 911 valid short", short_valid("US","911"), 1);
    ck_i("US 911 emergency", short_emerg("US","911"), 1);
    ck_i("US 999 not emergency", short_emerg("US","999"), 0);
    ck_i("GB 999 emergency", short_emerg("GB","999"), 1);
    ck_i("US 12 not possible short", short_possible("US","12"), 0);
    ck_i("US 911 toll-free cost", short_cost("US","911"), 0);
    ck_s("US short example", short_example("US"), "112");

    dlclose(H);
    if (failures) { fprintf(stderr, "abi_smoke: %d FAILURE(S)\n", failures); return 1; }
    printf("abi_smoke: PASS — full ABI conformance over dlopen\n");
    return 0;
}
