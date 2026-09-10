/* core/_embed_support.c — the irreducible C under the phonenumber C ABI.
 *
 * The phone-number ENGINE is pure Aether (core/phonenumber.ae + the generated
 * core/metadata.ae). This file carries only ONE thing Aether's stdlib cannot
 * express: the caller-owned-string bridge. There are NO callback trampolines
 * here — unlike the html-sanitizer sibling, this ABI has no hooks, no closures
 * and no opaque handle, because the engine is a pure stateless transform.
 *
 *   pn_raw_dup / pn_raw_free — every `char*` the ABI returns is a plain
 *   malloc'd, NUL-terminated copy that the host frees with
 *   aether_pn_embed_free_string(). Aether's std.mem is access-only (no
 *   allocation), and the bindings free returned pointers with C free(), so
 *   this cannot be Aether.
 *
 * Linked into the .so via `--extra` from core/.build.ae only.
 */
#include <stdlib.h>
#include <string.h>

/* Aether's string ABI (std/string/aether_string.h).
 *
 * An Aether `string` crossing a `const char*` slot is NOT necessarily a plain
 * C string: builtins hand back a refcounted `AetherString*` whose first bytes
 * are a magic header, not content. aether_string_data() accepts either shape
 * and returns the real byte pointer. Reading one raw is how you get mojibake,
 * so every inbound Aether string goes through it. */
const char* aether_string_data(const void* s);

/* ---- caller-owned string bridge ---- */

/* Duplicate an inbound Aether string into a plain malloc'd C string the host
 * owns. NULL and the AetherString magic header are both handled via
 * aether_string_data(). */
char* pn_raw_dup(const void* s) {
    const char* c = s ? aether_string_data(s) : "";
    if (!c) c = "";
    size_t n = strlen(c) + 1;
    char* d = (char*)malloc(n);
    if (d) memcpy(d, c, n);
    return d;
}

/* Free a string handed back to the host by pn_raw_dup. NULL-safe. */
void pn_raw_free(char* s) {
    free(s);
}
