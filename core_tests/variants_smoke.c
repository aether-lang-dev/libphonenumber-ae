/* Proves the validation-only variant .so: (1) has the core validation surface,
 * (2) does NOT export any side-library symbol (geo/carrier/tz/short), and
 * (3) is small (no ~7MB geocoder blob linked in). */
#include <dlfcn.h>
#include <stdio.h>
#include <sys/stat.h>
int main(int argc, char** argv) {
    const char* path = argc > 1 ? argv[1] : "./core/native/libphonenumber_ae_validation.so";
    void* h = dlopen(path, RTLD_NOW);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
    int fails = 0;
    /* core validation present + working */
    int (*valid)(const char*,const char*) = dlsym(h, "aether_pn_embed_is_valid_number");
    if (!valid) { fprintf(stderr, "FAIL: core is_valid_number missing\n"); fails++; }
    else if (valid("US","2015550123") != 1) { fprintf(stderr, "FAIL: US should validate\n"); fails++; }
    /* side-lib symbols must be ABSENT */
    if (dlsym(h, "aether_pn_embed_geo_description"))  { fprintf(stderr, "FAIL: geo symbol present in validation variant\n"); fails++; }
    if (dlsym(h, "aether_pn_embed_carrier_name"))     { fprintf(stderr, "FAIL: carrier symbol present\n"); fails++; }
    if (dlsym(h, "aether_pn_embed_tz_all"))           { fprintf(stderr, "FAIL: tz symbol present\n"); fails++; }
    if (dlsym(h, "aether_pn_embed_short_is_valid"))   { fprintf(stderr, "FAIL: short symbol present\n"); fails++; }
    /* small: no 7MB geocoder blob -> under 2MB is a generous ceiling */
    struct stat st;
    if (stat(path, &st) == 0 && st.st_size > 2*1024*1024) {
        fprintf(stderr, "FAIL: validation variant is %ld bytes (> 2MB — a data blob leaked in)\n", (long)st.st_size);
        fails++;
    }
    dlclose(h);
    if (fails) { fprintf(stderr, "variants_smoke: %d FAILURE(S)\n", fails); return 1; }
    printf("variants_smoke: PASS — validation variant is slim + side-lib-free\n");
    return 0;
}
