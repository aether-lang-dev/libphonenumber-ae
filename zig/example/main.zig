//! A small tour of the Zig binding: `zig build example`.
//!
//! Shows the v2 surface a caller actually needs — a country code, validity, the
//! four format styles, the number type, a full parse, an AsYouTypeFormatter and
//! a find-numbers pass over free text — with the one ownership rule made
//! explicit at every step: every returned slice is caller-owned.

const std = @import("std");
const pn = @import("phonenumber_ae");

pub fn main() !void {
    var debug = std.heap.DebugAllocator(.{}){};
    defer _ = debug.deinit(); // reports a leak on exit, which is the point
    const alloc = debug.allocator();

    // std.debug.print goes to stderr, which is fine for a demo and avoids the
    // stdout-writer churn between Zig releases.
    const p = std.debug.print;
    p("engine ABI version: {d}\n\n", .{pn.abiVersion()});

    {
        const cc = try pn.countryCode(alloc, "US");
        defer alloc.free(cc);
        p("country code US:  {s}\n", .{cc});
    }

    {
        const valid = try pn.isValidNumber(alloc, "US", "+1 201 555 0123");
        p("is valid:         {}\n", .{valid});
    }

    {
        const t = try pn.numberType(alloc, "US", "2015550123");
        p("number type:      {s}\n", .{@tagName(t)});
    }

    // v2 renumbered the format styles: e164 is now 0, not 2.
    inline for (.{ pn.Format.national, pn.Format.international, pn.Format.e164, pn.Format.rfc3966 }) |style| {
        const f = try pn.format(alloc, "US", "2015550123", style);
        defer alloc.free(f);
        p("format {s: <14} {s}\n", .{ @tagName(style), f });
    }

    // parse → a ParsedNumber, whose fields are read on demand.
    {
        var num = try pn.parse(alloc, "+1 201 555 0123 ext 42", "US");
        defer num.deinit();
        const nsn = try num.nationalNumber(alloc);
        defer alloc.free(nsn);
        const ext = try num.extension(alloc);
        defer alloc.free(ext);
        const rc = try num.regionCode(alloc);
        defer alloc.free(rc);
        p("\nparsed:           nsn={s} ext={s} region={s}\n", .{ nsn, ext, rc });
    }

    // AsYouTypeFormatter — feed the digits one at a time.
    {
        var ayt = try pn.asYouTypeFormatter(alloc, "US");
        defer ayt.deinit();
        var last: []u8 = try alloc.dupe(u8, "");
        defer alloc.free(last);
        for ("2015550123") |ch| {
            alloc.free(last);
            last = try ayt.inputDigit(ch);
        }
        p("as-you-type:      {s}\n", .{last});
    }

    // find numbers in free text.
    {
        const matches = try pn.findNumbers(alloc, "call 201-555-0123 or +1 202 555 0199", "US", .valid);
        defer pn.freeMatches(alloc, matches);
        p("found {d} number(s):\n", .{matches.len});
        for (matches) |m| p("  [{d}..{d}) {s}\n", .{ m.start, m.end, m.raw });
    }

    {
        const regs = try pn.regions(alloc);
        defer pn.freeRegions(alloc, regs);
        p("\nregions:          {d} known (first: {s})\n", .{ regs.len, regs[0] });
    }
}
