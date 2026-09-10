package org.libphonenumber.ae;

/**
 * Geographic descriptions — the idiomatic Java surface over the shared Aether
 * engine's {@code PhoneNumberOfflineGeocoder} side-library (ABI v6).
 *
 * <p>A longest-prefix match over the number's E.164 digits. Every call takes a
 * raw {@code (region, input)}; the engine parses to E.164 internally. English
 * descriptions only; {@code ""} means no description is known for the number.
 *
 * <pre>{@code
 * Geocoder.geoDescriptionForNumber("US", "6502530000");        // "Mountain View, CA"
 * Geocoder.geoDescriptionForValidNumber("US", "6502530000");   // "Mountain View, CA" (only if valid)
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
        Native a = api();
        return a.call2s(a.geoDescription, region, input);
    }

    /** A geographic description only when the number is valid, else {@code ""}. */
    public static String geoDescriptionForValidNumber(String region, String input) {
        Native a = api();
        return a.call2s(a.geoDescriptionForValid, region, input);
    }
}
