package org.libphonenumber.ae;

/**
 * Geographic descriptions — the idiomatic Java surface over the shared Aether
 * engine's {@code PhoneNumberOfflineGeocoder} side-library (ABI v7).
 *
 * <p>A longest-prefix match over the number's E.164 digits. Every call takes a
 * raw {@code (region, input)}; the engine parses to E.164 internally.
 * Descriptions are localized by {@code lang} (an ISO code such as {@code "en"},
 * {@code "de"}); {@code "en"} is always available and is the fallback for any
 * language not compiled into the engine. {@code ""} means no description is
 * known for the number.
 *
 * <pre>{@code
 * Geocoder.geoDescriptionForNumber("US", "6502530000");         // "Mountain View, CA" (English)
 * Geocoder.geoDescriptionForNumber("US", "6502530000", "de");   // localized to German
 * Geocoder.geoDescriptionForValidNumber("US", "6502530000");    // "Mountain View, CA" (only if valid)
 * }</pre>
 *
 * <p>Carries <b>no phone-number logic</b>: every method marshals to an
 * {@code aether_pn_embed_geo_*} call in {@link Native}. All methods are
 * static and stateless; the engine is loaded lazily and cached via
 * {@link Native#load}.
 *
 * <p>Requires {@code --enable-native-access=ALL-UNNAMED} on the command line.
 */
public final class Geocoder {

    private Geocoder() {
    }

    private static Native api() {
        return Native.load(null);
    }

    /** A geographic description for a number (English), or {@code ""} if none is known. */
    public static String geoDescriptionForNumber(String region, String input) {
        return geoDescriptionForNumber(region, input, "en");
    }

    /** A geographic description for a number, localized by {@code lang}, or {@code ""} if none is known. */
    public static String geoDescriptionForNumber(String region, String input, String lang) {
        Native a = api();
        return a.call3s(a.geoDescription, region, input, lang);
    }

    /** A geographic description only when the number is valid (English), else {@code ""}. */
    public static String geoDescriptionForValidNumber(String region, String input) {
        return geoDescriptionForValidNumber(region, input, "en");
    }

    /** A geographic description only when the number is valid, localized by {@code lang}, else {@code ""}. */
    public static String geoDescriptionForValidNumber(String region, String input, String lang) {
        Native a = api();
        return a.call3s(a.geoDescriptionForValid, region, input, lang);
    }
}
