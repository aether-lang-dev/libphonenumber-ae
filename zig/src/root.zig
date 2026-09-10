//! phonenumber_ae — the Zig binding over the monorepo's one shared native engine.
//!
//! Validate, parse and format international phone numbers.
//!
//! There is **no phone-number logic in this file**. The metadata table,
//! isPossible/isValid, number-type, the parser, the formatter, the
//! AsYouTypeFormatter and the matcher all live in `core/phonenumber.ae` (pure
//! Aether), exposed over the flat C ABI declared in `core/embed.ae`. This
//! module marshals values across that boundary and nothing else. If a behaviour
//! looks wrong, the bug is in the engine or in this marshalling — it is never a
//! policy decision made here.
//!
//! ## ABI v3
//!
//! This binding speaks **ABI v3** (`abiVersion()` → 3): the full
//! `PhoneNumberUtil` surface plus the `ShortNumberInfo` side-library, 58
//! exported symbols. The ABI is scalar-only (`const char*` and `int`) — v3 adds
//! no new mechanism, only more calls (the 8 `short_*` symbols). Two constructs
//! thread a *string* rather than an opaque handle:
//!
//!   * `parse` returns a caller-owned **parsed-number string**. Pass it to the
//!     `pn_*` accessors, then free it. `ParsedNumber` wraps that lifecycle.
//!   * The `AsYouTypeFormatter` state is likewise a caller-owned string:
//!     `ayt_input` returns a *new* state and you free the old. `AsYouType`
//!     wraps that.
//!
//! **A note on the format selector.** In v1 `e164` was `2`. In v2 the styles
//! are renumbered: **`e164 = 0`, `international = 1`, `national = 2`,
//! `rfc3966 = 3`.** If you were passing bare ints, re-check them; the `Format`
//! enum below is the safe way.
//!
//! ## Which family of binding is this?
//!
//! Like Go's cgo binding (and unlike Python/ctypes or Rust/libloading), this
//! one **links** the engine rather than `dlopen`ing it: the `extern "c"`
//! declarations below resolve at link time against `-lphonenumber_ae`. That
//! means the `.so` must exist when you *build*, not only when you run.
//! `build.zig` handles the `-L` and the `rpath`; see the README.
//!
//! Linking is the right trade for Zig specifically: Zig has no runtime, so
//! there is no GC to fight and no FFI marshalling layer to pay for. The whole
//! binding is therefore zero-overhead — it compiles to the same calls a
//! hand-written C consumer would make.
//!
//! ## The one rule that matters
//!
//! **Every `[*c]u8` this ABI returns is CALLER-OWNED.** It came from a plain
//! `malloc` inside the engine, and must go back through
//! `aether_pn_embed_free_string`. Forgetting this is the single most common
//! bug in a binding, so this file routes *every* returned string through
//! exactly one helper, `takeString`, which copies into a caller-supplied
//! allocator and frees the C buffer in a `defer` on the same line it acquired
//! it. There is no second path. Grep for `free_string` — it appears once.
//!
//! ## A note on integer widths
//!
//! The ABI is C `int` throughout (the format selector, the number-type result,
//! the region count). Every extern below uses `c_int`; the surface converts to
//! and from Zig's `i32`/enums at the edge. Declaring `c_long` anywhere would be
//! a 4-vs-8-byte mismatch on LP64.

const std = @import("std");

// =========================================================================
// The C ABI — a 1:1 transcription of core/embed.ae (v3, 58 symbols).
//
// `core/embed.ae` names its exports `pn_embed_<name>`; building with
// `--emit=lib` mangles them to `aether_pn_embed_<name>`, which is what we
// link against. Declaration order mirrors embed.ae / docs/abi.md so the two
// can be diffed by eye.
//
// Types: `[*c]const u8` for strings we hand in (C-pointer syntax so a Zig
// string literal's sentinel-terminated type coerces automatically), and
// `[*c]u8` for strings the ABI hands back — the pointer-ness is a reminder
// that we now own it.
// =========================================================================

const c = struct {
    // ---- lifecycle / metadata ----
    extern "c" fn aether_pn_embed_abi_version() c_int;
    extern "c" fn aether_pn_embed_free_string(s: [*c]u8) void;
    extern "c" fn aether_pn_embed_country_code(region: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_example_number(region: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_example_number_for_type(region: [*c]const u8, ntype: c_int) [*c]u8;
    extern "c" fn aether_pn_embed_invalid_example_number(region: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_possible_lengths(region: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_region_code_for_country_code(cc: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_is_nanpa_country(region: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_ndd_prefix_for_region(region: [*c]const u8, strip_non_digits: c_int) [*c]u8;
    extern "c" fn aether_pn_embed_region_count() c_int;
    extern "c" fn aether_pn_embed_region_at(index: c_int) [*c]u8;
    extern "c" fn aether_pn_embed_cc_region_count(cc: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_cc_region_at(cc: [*c]const u8, index: c_int) [*c]u8;

    // ---- parse + parsed-number accessors ----
    extern "c" fn aether_pn_embed_parse(input: [*c]const u8, region: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_national_number(region: [*c]const u8, input: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_pn_region(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_pn_country_code(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_pn_national_number(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_pn_extension(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_pn_italian_leading_zero(pn: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_pn_source(pn: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_pn_error(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_region_code_for_number(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_national_significant_number(pn: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_length_of_ndc(pn: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_length_of_area_code(pn: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_is_geographical(pn: [*c]const u8) c_int;

    // ---- validation ----
    extern "c" fn aether_pn_embed_is_possible_number(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_is_possible_number_with_reason(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_is_valid_number(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_is_valid_number_for_region(input: [*c]const u8, region: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_number_type(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_can_be_internationally_dialled(region: [*c]const u8, input: [*c]const u8) c_int;

    // ---- formatting ----
    extern "c" fn aether_pn_embed_format(region: [*c]const u8, input: [*c]const u8, fmt: c_int) [*c]u8;
    extern "c" fn aether_pn_embed_format_out_of_country(region: [*c]const u8, input: [*c]const u8, calling_from: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_format_in_original(pn: [*c]const u8, calling_from: [*c]const u8) [*c]u8;

    // ---- relations / helpers ----
    extern "c" fn aether_pn_embed_is_number_match(a: [*c]const u8, b: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_truncate_too_long(region: [*c]const u8, input: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_normalize_digits_only(s: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_convert_alpha_characters(s: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_is_alpha_number(s: [*c]const u8) c_int;

    // ---- AsYouTypeFormatter (state threaded as a caller-owned string) ----
    extern "c" fn aether_pn_embed_ayt_new(region: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_ayt_input(state: [*c]const u8, ch: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_ayt_result(state: [*c]const u8) [*c]u8;
    extern "c" fn aether_pn_embed_ayt_clear(state: [*c]const u8) [*c]u8;

    // ---- PhoneNumberMatcher / findNumbers ----
    extern "c" fn aether_pn_embed_matcher_count(text: [*c]const u8, region: [*c]const u8, leniency: c_int) c_int;
    extern "c" fn aether_pn_embed_matcher_start(text: [*c]const u8, region: [*c]const u8, leniency: c_int, idx: c_int) c_int;
    extern "c" fn aether_pn_embed_matcher_end(text: [*c]const u8, region: [*c]const u8, leniency: c_int, idx: c_int) c_int;
    extern "c" fn aether_pn_embed_matcher_raw(text: [*c]const u8, region: [*c]const u8, leniency: c_int, idx: c_int) [*c]u8;

    // ---- ShortNumberInfo (short / emergency numbers) ----
    extern "c" fn aether_pn_embed_short_is_possible(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_is_valid(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_is_emergency(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_connects_to_emergency(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_is_carrier_specific(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_is_sms_service(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_expected_cost(region: [*c]const u8, input: [*c]const u8) c_int;
    extern "c" fn aether_pn_embed_short_example_number(region: [*c]const u8) [*c]u8;
};

// =========================================================================
// ABI constants — append only, never renumber.
// =========================================================================

/// A phone-number format style. The values ARE the ABI's `fmt` selector; the
/// enum keeps callers from passing a bare int and meaning the wrong style.
///
/// **v2 renumbered these.** In v1 `e164` was `2`; it is now `0`.
pub const Format = enum(c_int) {
    e164 = 0,
    international = 1,
    national = 2,
    rfc3966 = 3,
};

/// The kind of number `numberType` reports. Non-exhaustive: the ABI is
/// append-only, so a future engine may return a code this build has no name
/// for, and that must not be illegal-value UB in a Zig enum. `unknown` is the
/// ABI's `-1`.
pub const NumberType = enum(c_int) {
    unknown = -1,
    fixed_line = 0,
    mobile = 1,
    toll_free = 2,
    premium_rate = 3,
    shared_cost = 4,
    voip = 5,
    personal_number = 6,
    pager = 7,
    uan = 8,
    voicemail = 9,
    fixed_line_or_mobile = 10,
    _,
};

/// The result of `isPossibleNumberWithReason`. Non-exhaustive for the same
/// append-only reason as `NumberType`.
pub const ValidationResult = enum(c_int) {
    is_possible = 0,
    invalid_country_code = 1,
    too_short = 2,
    too_long = 3,
    is_possible_local_only = 4,
    invalid_length = 5,
    _,
};

/// The result of `isNumberMatch`. Non-exhaustive.
pub const MatchType = enum(c_int) {
    not_a_number = 0,
    no_match = 1,
    short_nsn = 2,
    nsn = 3,
    exact = 4,
    _,
};

/// Where the country code on a parsed number came from (`ParsedNumber.source`).
/// Non-exhaustive.
pub const CountryCodeSource = enum(c_int) {
    from_number_with_plus = 1,
    from_number_with_idd = 5,
    from_number_without_plus = 10,
    from_default_country = 20,
    _,
};

/// How permissive the matcher is when scanning free text (`findNumbers`).
pub const Leniency = enum(c_int) {
    possible = 0,
    valid = 1,
};

/// The expected cost of dialling a short number (`shortExpectedCost`).
/// Non-exhaustive for the same append-only reason as `NumberType`.
pub const ShortNumberCost = enum(c_int) {
    toll_free = 0,
    standard_rate = 1,
    premium_rate = 2,
    unknown = 3,
    _,
};

// Bare integer aliases, for a caller who prefers the wire format to the enum.
// The `Format` group is the one that moved between v1 and v2 — mind it.
pub const E164: c_int = 0;
pub const INTERNATIONAL: c_int = 1;
pub const NATIONAL: c_int = 2;
pub const RFC3966: c_int = 3;

pub const TYPE_UNKNOWN: c_int = -1;
pub const TYPE_FIXED_LINE: c_int = 0;
pub const TYPE_MOBILE: c_int = 1;
pub const TYPE_TOLL_FREE: c_int = 2;
pub const TYPE_PREMIUM_RATE: c_int = 3;
pub const TYPE_SHARED_COST: c_int = 4;
pub const TYPE_VOIP: c_int = 5;
pub const TYPE_PERSONAL_NUMBER: c_int = 6;
pub const TYPE_PAGER: c_int = 7;
pub const TYPE_UAN: c_int = 8;
pub const TYPE_VOICEMAIL: c_int = 9;
pub const TYPE_FIXED_LINE_OR_MOBILE: c_int = 10;

pub const VR_IS_POSSIBLE: c_int = 0;
pub const VR_INVALID_COUNTRY_CODE: c_int = 1;
pub const VR_TOO_SHORT: c_int = 2;
pub const VR_TOO_LONG: c_int = 3;
pub const VR_IS_POSSIBLE_LOCAL_ONLY: c_int = 4;
pub const VR_INVALID_LENGTH: c_int = 5;

pub const MATCH_NOT_A_NUMBER: c_int = 0;
pub const MATCH_NO_MATCH: c_int = 1;
pub const MATCH_SHORT_NSN: c_int = 2;
pub const MATCH_NSN: c_int = 3;
pub const MATCH_EXACT: c_int = 4;

pub const SRC_FROM_NUMBER_WITH_PLUS: c_int = 1;
pub const SRC_FROM_NUMBER_WITH_IDD: c_int = 5;
pub const SRC_FROM_NUMBER_WITHOUT_PLUS: c_int = 10;
pub const SRC_FROM_DEFAULT_COUNTRY: c_int = 20;

pub const LENIENCY_POSSIBLE: c_int = 0;
pub const LENIENCY_VALID: c_int = 1;

pub const COST_TOLL_FREE: c_int = 0;
pub const COST_STANDARD_RATE: c_int = 1;
pub const COST_PREMIUM_RATE: c_int = 2;
pub const COST_UNKNOWN: c_int = 3;

pub const Error = error{
    /// A Zig string contained an interior NUL and cannot cross a C `char*`.
    InteriorNul,
    /// Out of memory copying an ABI string into Zig-owned storage.
    OutOfMemory,
};

/// The ABI revision this engine implements. Check it to fail fast against an
/// engine older than the features you expect — v3 is what this binding needs.
pub fn abiVersion() i32 {
    return @intCast(c.aether_pn_embed_abi_version());
}

// =========================================================================
// String marshalling — the ONE place returned strings are freed.
// =========================================================================

/// Copy an ABI-returned string into `allocator` and free the C buffer.
///
/// THE ownership rule lives here and nowhere else. Every function in this file
/// that receives a `[*c]u8` from the ABI hands it straight to this, so there is
/// exactly one `free_string` call site to audit. The `defer` is on the line
/// after acquisition so no early return can skip it.
///
/// A null return is treated as `""`. The ABI documents that it never returns
/// null (it dups `""` instead), but a null-deref is a worse failure mode than
/// an empty string.
fn takeString(allocator: std.mem.Allocator, ptr: [*c]u8) Error![]u8 {
    if (ptr == null) return allocator.dupe(u8, "") catch return Error.OutOfMemory;
    defer c.aether_pn_embed_free_string(ptr);
    const slice = std.mem.span(@as([*:0]u8, @ptrCast(ptr)));
    return allocator.dupe(u8, slice) catch Error.OutOfMemory;
}

/// Stack-buffer helper for handing a Zig slice to a C `const char*`.
///
/// A region id or a phone-number string is short, so we NUL-terminate in a
/// fixed buffer and avoid an allocation. Anything longer (a paragraph of text
/// for the matcher, say) falls back to the allocator.
const CStr = struct {
    buf: [512]u8 = undefined,
    heap: ?[]u8 = null,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, s: []const u8) Error!CStr {
        // An interior NUL would silently truncate the string at the C boundary.
        if (std.mem.indexOfScalar(u8, s, 0) != null) return Error.InteriorNul;
        var self = CStr{ .allocator = allocator };
        if (s.len + 1 <= self.buf.len) {
            @memcpy(self.buf[0..s.len], s);
            self.buf[s.len] = 0;
        } else {
            const h = allocator.alloc(u8, s.len + 1) catch return Error.OutOfMemory;
            @memcpy(h[0..s.len], s);
            h[s.len] = 0;
            self.heap = h;
        }
        return self;
    }

    fn ptr(self: *const CStr) [*c]const u8 {
        if (self.heap) |h| return h.ptr;
        return &self.buf;
    }

    fn deinit(self: *CStr) void {
        if (self.heap) |h| self.allocator.free(h);
        self.heap = null;
    }
};

// =========================================================================
// Metadata — every call marshals to one aether_pn_embed_* export.
//
// Each string result is caller-owned: free it with the same allocator you
// passed in. Each argument-taking function may return Error.InteriorNul.
// =========================================================================

/// The country calling code for a region ("1", "44", …), or "" if unknown.
pub fn countryCode(allocator: std.mem.Allocator, region: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_country_code(r.ptr()));
}

/// An example national number for the region, or "".
pub fn exampleNumber(allocator: std.mem.Allocator, region: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_example_number(r.ptr()));
}

/// An example number of a specific `NumberType` for the region, or "".
pub fn exampleNumberForType(allocator: std.mem.Allocator, region: []const u8, ntype: NumberType) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_example_number_for_type(r.ptr(), @intFromEnum(ntype)));
}

/// An example number that is INVALID for the region — for negative testing.
pub fn invalidExampleNumber(allocator: std.mem.Allocator, region: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_invalid_example_number(r.ptr()));
}

/// The possible-lengths spec for the region (e.g. "9,10"), or "".
pub fn possibleLengths(allocator: std.mem.Allocator, region: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_possible_lengths(r.ptr()));
}

/// The main region for a country calling code ("44" → "GB"), or "".
pub fn regionCodeForCountryCode(allocator: std.mem.Allocator, cc: []const u8) Error![]u8 {
    var x = try CStr.init(allocator, cc);
    defer x.deinit();
    return takeString(allocator, c.aether_pn_embed_region_code_for_country_code(x.ptr()));
}

/// True if the region is part of the North American Numbering Plan.
pub fn isNanpaCountry(allocator: std.mem.Allocator, region: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return c.aether_pn_embed_is_nanpa_country(r.ptr()) != 0;
}

/// The national-direct-dialling prefix for the region (e.g. "1", "0"), or "".
/// When `strip_non_digits` is true, formatting hints like `~` are removed.
pub fn nddPrefixForRegion(allocator: std.mem.Allocator, region: []const u8, strip_non_digits: bool) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_ndd_prefix_for_region(r.ptr(), if (strip_non_digits) 1 else 0));
}

/// How many region ids the metadata carries.
pub fn regionCount() usize {
    const n = c.aether_pn_embed_region_count();
    return if (n < 0) 0 else @intCast(n);
}

/// The region id at `index` in the engine's own order; "" when out of range.
/// Caller frees.
pub fn regionAt(allocator: std.mem.Allocator, index: usize) Error![]u8 {
    return takeString(allocator, c.aether_pn_embed_region_at(@intCast(index)));
}

/// Every region id the metadata carries. Caller frees both the outer slice and
/// each string — `freeRegions` does both.
pub fn regions(allocator: std.mem.Allocator) Error![][]u8 {
    const n = regionCount();
    const out = allocator.alloc([]u8, n) catch return Error.OutOfMemory;
    var filled: usize = 0;
    errdefer {
        for (out[0..filled]) |s| allocator.free(s);
        allocator.free(out);
    }
    while (filled < n) : (filled += 1) {
        out[filled] = try regionAt(allocator, filled);
    }
    return out;
}

pub fn freeRegions(allocator: std.mem.Allocator, list: [][]u8) void {
    for (list) |s| allocator.free(s);
    allocator.free(list);
}

/// How many regions share a country calling code (NANPA "1" → many).
pub fn ccRegionCount(allocator: std.mem.Allocator, cc: []const u8) Error!usize {
    var x = try CStr.init(allocator, cc);
    defer x.deinit();
    const n = c.aether_pn_embed_cc_region_count(x.ptr());
    return if (n < 0) 0 else @intCast(n);
}

/// The `index`-th region sharing a country calling code; "" when out of range.
/// Caller frees.
pub fn ccRegionAt(allocator: std.mem.Allocator, cc: []const u8, index: usize) Error![]u8 {
    var x = try CStr.init(allocator, cc);
    defer x.deinit();
    return takeString(allocator, c.aether_pn_embed_cc_region_at(x.ptr(), @intCast(index)));
}

/// Every region sharing a country calling code. Caller frees via `freeRegions`.
pub fn regionsForCountryCode(allocator: std.mem.Allocator, cc: []const u8) Error![][]u8 {
    const n = try ccRegionCount(allocator, cc);
    const out = allocator.alloc([]u8, n) catch return Error.OutOfMemory;
    var filled: usize = 0;
    errdefer {
        for (out[0..filled]) |s| allocator.free(s);
        allocator.free(out);
    }
    while (filled < n) : (filled += 1) {
        out[filled] = try ccRegionAt(allocator, cc, filled);
    }
    return out;
}

// =========================================================================
// Parsed number.
//
// `parse` returns a caller-owned parsed-number STRING. `ParsedNumber` owns
// that string and reads its fields on demand through the `pn_*` accessors.
// Call `deinit` to free the underlying string. Each string accessor copies
// into `allocator` and frees the C buffer; the caller frees the copy.
// =========================================================================

/// A parsed phone number. Wraps the caller-owned parsed-number string the ABI
/// returns; its fields are read on demand. `deinit` frees the wrapped string.
pub const ParsedNumber = struct {
    allocator: std.mem.Allocator,
    /// The caller-owned parsed-number string. Owned by this struct.
    raw: []u8,

    /// Free the wrapped parsed-number string.
    pub fn deinit(self: *ParsedNumber) void {
        self.allocator.free(self.raw);
        self.raw = &[_]u8{};
    }

    fn cstr(self: *const ParsedNumber, allocator: std.mem.Allocator) Error!CStr {
        return CStr.init(allocator, self.raw);
    }

    /// The region this number was parsed against ("US", …), or "".
    pub fn region(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_pn_region(p.ptr()));
    }

    /// The country calling code as a string ("1", "44", …), or "".
    pub fn countryCode(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_pn_country_code(p.ptr()));
    }

    /// The national (significant) number as a string.
    pub fn nationalNumber(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_pn_national_number(p.ptr()));
    }

    /// The extension, or "" if none.
    pub fn extension(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_pn_extension(p.ptr()));
    }

    /// True if the number carries an Italian-style leading zero.
    pub fn italianLeadingZero(self: *const ParsedNumber, allocator: std.mem.Allocator) Error!bool {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return c.aether_pn_embed_pn_italian_leading_zero(p.ptr()) != 0;
    }

    /// Where the country code came from (a `CountryCodeSource`).
    pub fn source(self: *const ParsedNumber, allocator: std.mem.Allocator) Error!CountryCodeSource {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return @enumFromInt(c.aether_pn_embed_pn_source(p.ptr()));
    }

    /// A non-empty parse-error message if the parse failed, else "".
    pub fn parseError(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_pn_error(p.ptr()));
    }

    /// The region the number actually belongs to, derived from the number
    /// itself ("US", …), or "".
    pub fn regionCode(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_region_code_for_number(p.ptr()));
    }

    /// The national significant number (canonical form).
    pub fn nationalSignificantNumber(self: *const ParsedNumber, allocator: std.mem.Allocator) Error![]u8 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return takeString(allocator, c.aether_pn_embed_national_significant_number(p.ptr()));
    }

    /// Length of the national destination code (area/carrier), or 0.
    pub fn lengthOfNdc(self: *const ParsedNumber, allocator: std.mem.Allocator) Error!i32 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return @intCast(c.aether_pn_embed_length_of_ndc(p.ptr()));
    }

    /// Length of the area code, or 0.
    pub fn lengthOfAreaCode(self: *const ParsedNumber, allocator: std.mem.Allocator) Error!i32 {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return @intCast(c.aether_pn_embed_length_of_area_code(p.ptr()));
    }

    /// True if the number is geographically bound (has an area code).
    pub fn isGeographical(self: *const ParsedNumber, allocator: std.mem.Allocator) Error!bool {
        var p = try self.cstr(allocator);
        defer p.deinit();
        return c.aether_pn_embed_is_geographical(p.ptr()) != 0;
    }
};

/// Parse a raw human-typed number against a default region. Returns a
/// `ParsedNumber` you must `deinit`. Check `parseError()` for failure; the
/// accessors read the fields. On a parse failure the string still round-trips —
/// the accessors return empties and `parseError()` explains.
pub fn parse(allocator: std.mem.Allocator, input: []const u8, region: []const u8) Error!ParsedNumber {
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    const raw = try takeString(allocator, c.aether_pn_embed_parse(i.ptr(), r.ptr()));
    return ParsedNumber{ .allocator = allocator, .raw = raw };
}

/// The national number extracted from raw input (cc + punctuation stripped).
/// A convenience over parse for the common case; caller frees.
pub fn nationalNumber(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return takeString(allocator, c.aether_pn_embed_national_number(r.ptr(), i.ptr()));
}

// =========================================================================
// Validation.
// =========================================================================

/// True if the national number is a length the region allows.
pub fn isPossibleNumber(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_is_possible_number(r.ptr(), i.ptr()) != 0;
}

/// A `ValidationResult` explaining possibility (`.too_short`, `.too_long`, …).
pub fn isPossibleNumberWithReason(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!ValidationResult {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return @enumFromInt(c.aether_pn_embed_is_possible_number_with_reason(r.ptr(), i.ptr()));
}

/// True if the number matches the region's national-number patterns.
pub fn isValidNumber(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_is_valid_number(r.ptr(), i.ptr()) != 0;
}

/// True if the number is valid *for* the given region specifically (argument
/// order is `input, region`, matching the ABI).
pub fn isValidNumberForRegion(allocator: std.mem.Allocator, input: []const u8, region: []const u8) Error!bool {
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return c.aether_pn_embed_is_valid_number_for_region(i.ptr(), r.ptr()) != 0;
}

/// The kind of number (a `NumberType`; `.unknown` for unknown).
pub fn numberType(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!NumberType {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return @enumFromInt(c.aether_pn_embed_number_type(r.ptr(), i.ptr()));
}

/// True if the number can be dialled from outside its own country.
pub fn canBeInternationallyDialled(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_can_be_internationally_dialled(r.ptr(), i.ptr()) != 0;
}

// =========================================================================
// Formatting.
// =========================================================================

/// Format the number in the given style. Caller owns the returned slice.
pub fn format(allocator: std.mem.Allocator, region: []const u8, input: []const u8, style: Format) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return takeString(allocator, c.aether_pn_embed_format(r.ptr(), i.ptr(), @intFromEnum(style)));
}

/// Format as it would be dialled from `calling_from` (IDD prefix and all).
pub fn formatOutOfCountry(allocator: std.mem.Allocator, region: []const u8, input: []const u8, calling_from: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    var f = try CStr.init(allocator, calling_from);
    defer f.deinit();
    return takeString(allocator, c.aether_pn_embed_format_out_of_country(r.ptr(), i.ptr(), f.ptr()));
}

/// Format a parsed number in its original (as-typed-ish) shape, as seen from
/// `calling_from`. Caller frees.
pub fn formatInOriginal(allocator: std.mem.Allocator, parsed: *const ParsedNumber, calling_from: []const u8) Error![]u8 {
    var p = try CStr.init(allocator, parsed.raw);
    defer p.deinit();
    var f = try CStr.init(allocator, calling_from);
    defer f.deinit();
    return takeString(allocator, c.aether_pn_embed_format_in_original(p.ptr(), f.ptr()));
}

// =========================================================================
// Relations / helpers.
// =========================================================================

/// Compare two numbers, returning a `MatchType` (`.exact`, `.no_match`, …).
pub fn isNumberMatch(allocator: std.mem.Allocator, a: []const u8, b: []const u8) Error!MatchType {
    var x = try CStr.init(allocator, a);
    defer x.deinit();
    var y = try CStr.init(allocator, b);
    defer y.deinit();
    return @enumFromInt(c.aether_pn_embed_is_number_match(x.ptr(), y.ptr()));
}

/// Truncate an over-long number to the longest valid length for the region.
pub fn truncateTooLong(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return takeString(allocator, c.aether_pn_embed_truncate_too_long(r.ptr(), i.ptr()));
}

/// Strip everything but the digits (and a leading plus is dropped too).
pub fn normalizeDigitsOnly(allocator: std.mem.Allocator, s: []const u8) Error![]u8 {
    var x = try CStr.init(allocator, s);
    defer x.deinit();
    return takeString(allocator, c.aether_pn_embed_normalize_digits_only(x.ptr()));
}

/// Convert vanity letters to their dial-pad digits ("FLOWERS" → "3569377").
pub fn convertAlphaCharacters(allocator: std.mem.Allocator, s: []const u8) Error![]u8 {
    var x = try CStr.init(allocator, s);
    defer x.deinit();
    return takeString(allocator, c.aether_pn_embed_convert_alpha_characters(x.ptr()));
}

/// True if the string contains vanity letters that map to digits.
pub fn isAlphaNumber(allocator: std.mem.Allocator, s: []const u8) Error!bool {
    var x = try CStr.init(allocator, s);
    defer x.deinit();
    return c.aether_pn_embed_is_alpha_number(x.ptr()) != 0;
}

// =========================================================================
// AsYouTypeFormatter.
//
// The formatter's whole state is a caller-owned string. `inputDigit` feeds one
// character and returns the formatted-so-far string; internally it acquires a
// NEW state and frees the old. `deinit` frees the current state.
// =========================================================================

/// Formats a number as it is typed, digit by digit. `deinit` when done.
pub const AsYouType = struct {
    allocator: std.mem.Allocator,
    /// The current formatter state, itself a caller-owned string.
    state: []u8,

    /// Free the current formatter state.
    pub fn deinit(self: *AsYouType) void {
        self.allocator.free(self.state);
        self.state = &[_]u8{};
    }

    /// Feed one character. Returns the formatted-so-far string (caller frees).
    /// The old state is freed and replaced with the new one.
    pub fn inputDigit(self: *AsYouType, ch: u8) Error![]u8 {
        var s = try CStr.init(self.allocator, self.state);
        defer s.deinit();
        const one = [_]u8{ch};
        var chs = try CStr.init(self.allocator, one[0..]);
        defer chs.deinit();
        const next = try takeString(self.allocator, c.aether_pn_embed_ayt_input(s.ptr(), chs.ptr()));
        self.allocator.free(self.state);
        self.state = next;
        return self.result();
    }

    /// The formatted-so-far string for the current state (caller frees).
    pub fn result(self: *const AsYouType) Error![]u8 {
        var s = try CStr.init(self.allocator, self.state);
        defer s.deinit();
        return takeString(self.allocator, c.aether_pn_embed_ayt_result(s.ptr()));
    }

    /// Reset the formatter, discarding what has been typed so far.
    pub fn clear(self: *AsYouType) Error!void {
        var s = try CStr.init(self.allocator, self.state);
        defer s.deinit();
        const next = try takeString(self.allocator, c.aether_pn_embed_ayt_clear(s.ptr()));
        self.allocator.free(self.state);
        self.state = next;
    }
};

/// Create an AsYouTypeFormatter for a region. `deinit` it when done.
pub fn asYouTypeFormatter(allocator: std.mem.Allocator, region: []const u8) Error!AsYouType {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    const state = try takeString(allocator, c.aether_pn_embed_ayt_new(r.ptr()));
    return AsYouType{ .allocator = allocator, .state = state };
}

// =========================================================================
// PhoneNumberMatcher / findNumbers.
//
// Find phone numbers embedded in free text. `findNumbers` returns a slice of
// `Match`, each carrying the [start, end) byte offsets and the raw matched
// substring (owned). Free with `freeMatches`.
// =========================================================================

/// One phone number found in free text. `raw` is owned by the `Match`.
pub const Match = struct {
    start: i32,
    end: i32,
    raw: []u8,
};

/// How many phone numbers `leniency` finds in `text` (default region `region`).
pub fn matcherCount(allocator: std.mem.Allocator, text: []const u8, region: []const u8, leniency: Leniency) Error!usize {
    var t = try CStr.init(allocator, text);
    defer t.deinit();
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    const n = c.aether_pn_embed_matcher_count(t.ptr(), r.ptr(), @intFromEnum(leniency));
    return if (n < 0) 0 else @intCast(n);
}

/// Find every phone number in `text`. Caller frees via `freeMatches`.
pub fn findNumbers(allocator: std.mem.Allocator, text: []const u8, region: []const u8, leniency: Leniency) Error![]Match {
    var t = try CStr.init(allocator, text);
    defer t.deinit();
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    const lev = @intFromEnum(leniency);
    const raw_n = c.aether_pn_embed_matcher_count(t.ptr(), r.ptr(), lev);
    const n: usize = if (raw_n < 0) 0 else @intCast(raw_n);

    const out = allocator.alloc(Match, n) catch return Error.OutOfMemory;
    var filled: usize = 0;
    errdefer {
        for (out[0..filled]) |m| allocator.free(m.raw);
        allocator.free(out);
    }
    while (filled < n) : (filled += 1) {
        const idx: c_int = @intCast(filled);
        const start = c.aether_pn_embed_matcher_start(t.ptr(), r.ptr(), lev, idx);
        const end = c.aether_pn_embed_matcher_end(t.ptr(), r.ptr(), lev, idx);
        const raw = try takeString(allocator, c.aether_pn_embed_matcher_raw(t.ptr(), r.ptr(), lev, idx));
        out[filled] = Match{ .start = @intCast(start), .end = @intCast(end), .raw = raw };
    }
    return out;
}

pub fn freeMatches(allocator: std.mem.Allocator, list: []Match) void {
    for (list) |m| allocator.free(m.raw);
    allocator.free(list);
}

// =========================================================================
// ShortNumberInfo (short / emergency numbers).
//
// Short numbers are dialled as-is — no country code, no national prefix — so
// the input is the raw short number plus a region. Pure marshalling, like the
// rest: no phone logic lives here.
// =========================================================================

/// True if `input` is a possible short number for the region (right length).
pub fn shortIsPossible(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_short_is_possible(r.ptr(), i.ptr()) != 0;
}

/// True if `input` matches a short-number pattern for the region.
pub fn shortIsValid(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_short_is_valid(r.ptr(), i.ptr()) != 0;
}

/// True if `input` is an emergency number for the region (e.g. US "911").
pub fn isEmergencyNumber(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_short_is_emergency(r.ptr(), i.ptr()) != 0;
}

/// True if dialling `input` connects to an emergency number for the region.
pub fn connectsToEmergencyNumber(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_short_connects_to_emergency(r.ptr(), i.ptr()) != 0;
}

/// True if the short number is specific to a single carrier.
pub fn shortIsCarrierSpecific(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_short_is_carrier_specific(r.ptr(), i.ptr()) != 0;
}

/// True if the short number is usable as an SMS service.
pub fn shortIsSmsService(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!bool {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return c.aether_pn_embed_short_is_sms_service(r.ptr(), i.ptr()) != 0;
}

/// The expected cost of dialling the short number (a `ShortNumberCost`).
pub fn shortExpectedCost(allocator: std.mem.Allocator, region: []const u8, input: []const u8) Error!ShortNumberCost {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    var i = try CStr.init(allocator, input);
    defer i.deinit();
    return @enumFromInt(c.aether_pn_embed_short_expected_cost(r.ptr(), i.ptr()));
}

/// An example short number for the region, or "". Caller frees.
pub fn shortExampleNumber(allocator: std.mem.Allocator, region: []const u8) Error![]u8 {
    var r = try CStr.init(allocator, region);
    defer r.deinit();
    return takeString(allocator, c.aether_pn_embed_short_example_number(r.ptr()));
}

test {
    // Pull the conformance suite into `zig build test`.
    _ = @import("conformance.zig");
}
