package org.libphonenumber.ae;

/**
 * A parsed phone number, produced by {@link PhoneNumbers#parse(String, String)}.
 *
 * <p>Wraps the caller-owned parsed-number <em>string</em> the ABI hands back
 * (there are no opaque handles in this ABI). Each field is read on demand by
 * passing that string to a {@code pn_*} accessor; nothing is cached, so this
 * object is a lightweight, immutable view over the underlying result.
 *
 * <p>Carries <b>no phone-number logic</b> — every accessor marshals to an
 * {@code aether_pn_embed_*} call in {@link Native}.
 */
public final class ParsedNumber {

    private final String pn;

    ParsedNumber(String pn) {
        this.pn = pn == null ? "" : pn;
    }

    private static Native api() {
        return Native.load(null);
    }

    /** The opaque parsed-number string this view wraps (as returned by {@code parse}). */
    String raw() {
        return pn;
    }

    /** The region the number was parsed against, e.g. {@code "US"}. */
    public String region() {
        Native a = api();
        return a.call1s(a.pnRegion, pn);
    }

    /** The country calling code, e.g. {@code "1"}. */
    public String countryCode() {
        Native a = api();
        return a.call1s(a.pnCountryCode, pn);
    }

    /** The national (significant) number as digits, e.g. {@code "2015550123"}. */
    public String nationalNumber() {
        Native a = api();
        return a.call1s(a.pnNationalNumber, pn);
    }

    /** The extension, or {@code ""} if none. */
    public String extension() {
        Native a = api();
        return a.call1s(a.pnExtension, pn);
    }

    /** Whether the number carries a leading zero (Italian-style). */
    public boolean italianLeadingZero() {
        Native a = api();
        return a.calli1s(a.pnItalianLeadingZero, pn) != 0;
    }

    /** How the country code was determined, as an ABI int. */
    public int sourceCode() {
        Native a = api();
        return a.calli1s(a.pnSource, pn);
    }

    /** How the country code was determined, as a {@link CountryCodeSource} (may be {@code null}). */
    public CountryCodeSource source() {
        return CountryCodeSource.of(sourceCode());
    }

    /** A non-empty message if the parse failed, else {@code ""}. */
    public String error() {
        Native a = api();
        return a.call1s(a.pnError, pn);
    }

    /** Whether the parse succeeded (i.e. {@link #error()} is empty). */
    public boolean isValid() {
        return error().isEmpty();
    }

    /** The region this number maps to, e.g. {@code "US"} (may differ from {@link #region()}). */
    public String regionCode() {
        Native a = api();
        return a.call1s(a.regionCodeForNumber, pn);
    }

    /** The national significant number, punctuation stripped. */
    public String nationalSignificantNumber() {
        Native a = api();
        return a.call1s(a.nationalSignificantNumber, pn);
    }

    /** The length of the national destination code, or {@code 0}. */
    public int lengthOfNationalDestinationCode() {
        Native a = api();
        return a.calli1s(a.lengthOfNdc, pn);
    }

    /** The length of the area code, or {@code 0}. */
    public int lengthOfAreaCode() {
        Native a = api();
        return a.calli1s(a.lengthOfAreaCode, pn);
    }

    /** Whether the number is geographically bound (i.e. has an area code). */
    public boolean isGeographical() {
        Native a = api();
        return a.calli1s(a.isGeographical, pn) != 0;
    }

    /** Re-render this number the way it was originally dialled, from {@code callingFrom}. */
    public String formatInOriginal(String callingFrom) {
        Native a = api();
        return a.call2s(a.formatInOriginal, pn, callingFrom);
    }

    @Override
    public String toString() {
        return "ParsedNumber{cc=" + countryCode() + ", nsn=" + nationalNumber()
                + ", ext=" + extension() + ", region=" + regionCode() + "}";
    }
}
