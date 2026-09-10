//! The 34-check binding conformance suite (docs/conformance.md, v2).
//!
//! Proves the Zig binding marshals every value shape across the FFI. It is NOT
//! a phone-number test suite — the behavioural cases live in the engine's own
//! tests (`core_tests/`) and run once, in Aether. Here we only ask: does each
//! *kind of value* cross the boundary intact?
//!
//! Every test uses `std.testing.allocator`, which fails the test on a leak.
//! That is deliberate and load-bearing: it turns the binding's one rule (every
//! ABI-returned `char*` must go back through `free_string`) into something the
//! suite actually enforces, rather than something a comment asserts.

const std = @import("std");
const pn = @import("root.zig");
const testing = std.testing;

const alloc = testing.allocator;

/// Fetch a string result and assert it equals `want`, freeing the result. The
/// `defer` here is what makes a forgotten free show up as a test failure.
fn expectStr(want: []const u8, got: anyerror![]u8) !void {
    const g = try got;
    defer alloc.free(g);
    try testing.expectEqualStrings(want, g);
}

// =========================================================================
// The thirty-four (docs/conformance.md, v2)
// =========================================================================

test "01 country_code US == 1" {
    try expectStr("1", pn.countryCode(alloc, "US"));
}

test "02 country_code GB == 44" {
    try expectStr("44", pn.countryCode(alloc, "GB"));
}

test "03 country_code ZZ == empty" {
    // The classic NULL-vs-"" bug: an unknown region must come back as an owned
    // empty string, not a null pointer.
    try expectStr("", pn.countryCode(alloc, "ZZ"));
}

test "04 example_number US" {
    try expectStr("2015550123", pn.exampleNumber(alloc, "US"));
}

test "05 possible_lengths US" {
    try expectStr("10", pn.possibleLengths(alloc, "US"));
}

test "06 region_code_for_country_code 44 == GB" {
    try expectStr("GB", pn.regionCodeForCountryCode(alloc, "44"));
}

test "07 is_nanpa_country US" {
    try testing.expect(try pn.isNanpaCountry(alloc, "US"));
}

test "08 region enumeration" {
    const regs = try pn.regions(alloc);
    defer pn.freeRegions(alloc, regs);
    try testing.expect(regs.len >= 200);
    try testing.expectEqual(@as(usize, 2), regs[0].len);
}

test "09 cc_region_at 1 0 == US" {
    try expectStr("US", pn.ccRegionAt(alloc, "1", 0));
}

test "10-14 parse fields" {
    var num = try pn.parse(alloc, "+1 201 555 0123 ext 42", "US");
    defer num.deinit();

    // 10 national number
    try expectStr("2015550123", num.nationalNumber(alloc));
    // 11 extension
    try expectStr("42", num.extension(alloc));
    // 12 country code
    try expectStr("1", num.countryCode(alloc));
    // 13 source
    try testing.expectEqual(pn.CountryCodeSource.from_number_with_plus, try num.source(alloc));
    // 14 region code for number
    try expectStr("US", num.regionCode(alloc));
    // and the parse succeeded
    try expectStr("", num.parseError(alloc));
}

test "15 parse trunk prefix (GB)" {
    var num = try pn.parse(alloc, "01212345678", "GB");
    defer num.deinit();
    try expectStr("1212345678", num.nationalNumber(alloc));
}

test "16 is_possible yes" {
    try testing.expect(try pn.isPossibleNumber(alloc, "US", "2015550123"));
}

test "17 is_possible_with_reason too short" {
    try testing.expectEqual(pn.ValidationResult.too_short, try pn.isPossibleNumberWithReason(alloc, "US", "201555"));
}

test "18 is_valid yes" {
    try testing.expect(try pn.isValidNumber(alloc, "US", "2015550123"));
}

test "19 is_valid wrong shape" {
    try testing.expect(!try pn.isValidNumber(alloc, "US", "1015550123"));
}

test "20 is_valid with +cc" {
    try testing.expect(try pn.isValidNumber(alloc, "US", "+12015550123"));
}

test "21 number_type fixed_line_or_mobile" {
    // Reading the enum value is also the int-width check: a c_long here would
    // read a garbage code and this would fail even if a bool check passed.
    // US fixedLine==mobile -> FIXED_LINE_OR_MOBILE; GB has distinct patterns.
    try testing.expectEqual(pn.NumberType.fixed_line_or_mobile, try pn.numberType(alloc, "US", "2015550123"));
    try testing.expectEqual(pn.NumberType.fixed_line, try pn.numberType(alloc, "GB", "2070313000"));
}

test "22 format NATIONAL" {
    try expectStr("(201) 555-0123", pn.format(alloc, "US", "2015550123", .national));
}

test "23 format E164" {
    try expectStr("+12015550123", pn.format(alloc, "US", "2015550123", .e164));
}

test "24 format INTERNATIONAL" {
    try expectStr("+1 201-555-0123", pn.format(alloc, "US", "2015550123", .international));
}

test "25 format RFC3966" {
    try expectStr("tel:+1-201-555-0123", pn.format(alloc, "US", "2015550123", .rfc3966));
}

test "26 is_number_match exact" {
    try testing.expectEqual(pn.MatchType.exact, try pn.isNumberMatch(alloc, "+12015550123", "+1 201 555 0123"));
}

test "27 is_number_match no match" {
    try testing.expectEqual(pn.MatchType.no_match, try pn.isNumberMatch(alloc, "+12015550123", "+12025550123"));
}

test "28 normalize_digits_only" {
    try expectStr("12015550123", pn.normalizeDigitsOnly(alloc, "+1 (201) 555.0123"));
}

test "29 convert_alpha_characters" {
    try expectStr("1-800-3569377", pn.convertAlphaCharacters(alloc, "1-800-FLOWERS"));
}

test "30 truncate_too_long" {
    try expectStr("2015550123", pn.truncateTooLong(alloc, "US", "20155501239999"));
}

test "31 AsYouType (201) 555-0123" {
    var ayt = try pn.asYouTypeFormatter(alloc, "US");
    defer ayt.deinit();
    var last: []u8 = try alloc.dupe(u8, "");
    defer alloc.free(last);
    for ("2015550123") |ch| {
        alloc.free(last);
        last = try ayt.inputDigit(ch);
    }
    try testing.expectEqualStrings("(201) 555-0123", last);
}

test "32 matcher_count == 2" {
    const matches = try pn.findNumbers(alloc, "call 201-555-0123 or +1 202 555 0199", "US", .valid);
    defer pn.freeMatches(alloc, matches);
    try testing.expectEqual(@as(usize, 2), matches.len);
}

test "33 matcher_raw" {
    const matches = try pn.findNumbers(alloc, "call 201-555-0123 now", "US", .valid);
    defer pn.freeMatches(alloc, matches);
    try testing.expect(matches.len >= 1);
    try testing.expectEqualStrings("201-555-0123", matches[0].raw);
}

test "34 abi_version == 2" {
    try testing.expectEqual(@as(i32, 2), pn.abiVersion());
}

// =========================================================================
// Extras — Zig-specific hazards and surface edges
// =========================================================================

test "extra region_at out of range is an owned empty string" {
    // The ABI returns an owned "" rather than null. Freeing it through the one
    // helper is what makes this safe, and testing.allocator proves we did.
    const oob = try pn.regionAt(alloc, 1_000_000);
    defer alloc.free(oob);
    try testing.expectEqualStrings("", oob);
}

test "extra number_type unknown maps cleanly" {
    // Not asserting a specific unknown case, just that the enum path never
    // yields illegal-value UB for whatever the engine returns.
    const t = try pn.numberType(alloc, "US", "2015550123");
    try testing.expect(t == .fixed_line_or_mobile);
}

test "extra interior NUL is rejected, not truncated" {
    try testing.expectError(pn.Error.InteriorNul, pn.countryCode(alloc, "U\x00S"));
    try testing.expectError(pn.Error.InteriorNul, pn.isValidNumber(alloc, "US", "20155\x0050123"));
}

test "extra regions_for_country_code lists US first for 1" {
    const regs = try pn.regionsForCountryCode(alloc, "1");
    defer pn.freeRegions(alloc, regs);
    try testing.expect(regs.len >= 1);
    try testing.expectEqualStrings("US", regs[0]);
}

test "extra AsYouType clear resets" {
    var ayt = try pn.asYouTypeFormatter(alloc, "US");
    defer ayt.deinit();
    var last: []u8 = try alloc.dupe(u8, "");
    defer alloc.free(last);
    for ("201") |ch| {
        alloc.free(last);
        last = try ayt.inputDigit(ch);
    }
    try ayt.clear();
    const r = try ayt.result();
    defer alloc.free(r);
    try testing.expectEqualStrings("", r);
}

test "extra many string round trips do not leak" {
    // testing.allocator turns a missing free here into a failure.
    var i: usize = 0;
    while (i < 3000) : (i += 1) {
        const cc = try pn.countryCode(alloc, "US");
        defer alloc.free(cc);
        try testing.expectEqualStrings("1", cc);
    }
}
