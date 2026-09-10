package org.libphonenumber.ae;

/**
 * Carrier names — the idiomatic Java surface over the shared Aether engine's
 * {@code PhoneNumberToCarrierMapper} side-library (ABI v7).
 *
 * <p>A longest-prefix match over the number's E.164 digits. Every call takes a
 * raw {@code (region, input)}; the engine parses to E.164 internally. Names are
 * localized by {@code lang} (an ISO code such as {@code "en"}, {@code "de"});
 * {@code "en"} is always available and is the fallback for any language not
 * compiled into the engine. {@code ""} means no carrier is known for the number.
 *
 * <pre>{@code
 * Carrier.carrierNameForNumber("GB", "7106000000");         // "O2" (English)
 * Carrier.carrierNameForNumber("GB", "7106000000", "de");   // localized to German
 * Carrier.carrierNameForValidNumber("GB", "7106000000");    // "O2" (only if valid)
 * }</pre>
 *
 * <p>Carries <b>no phone-number logic</b>: every method marshals to an
 * {@code aether_pn_embed_carrier_*} call in {@link Native}. All methods are
 * static and stateless; the engine is loaded lazily and cached via
 * {@link Native#load}.
 *
 * <p>Requires {@code --enable-native-access=ALL-UNNAMED} on the command line.
 */
public final class Carrier {

    private Carrier() {
    }

    private static Native api() {
        return Native.load(null);
    }

    /** The carrier name for a number (English), or {@code ""} if none is known. */
    public static String carrierNameForNumber(String region, String input) {
        return carrierNameForNumber(region, input, "en");
    }

    /** The carrier name for a number, localized by {@code lang}, or {@code ""} if none is known. */
    public static String carrierNameForNumber(String region, String input, String lang) {
        Native a = api();
        return a.call3s(a.carrierName, region, input, lang);
    }

    /** The carrier name only when the number is valid (English), else {@code ""}. */
    public static String carrierNameForValidNumber(String region, String input) {
        return carrierNameForValidNumber(region, input, "en");
    }

    /** The carrier name only when the number is valid, localized by {@code lang}, else {@code ""}. */
    public static String carrierNameForValidNumber(String region, String input, String lang) {
        Native a = api();
        return a.call3s(a.carrierNameForValid, region, input, lang);
    }
}
