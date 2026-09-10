package org.libphonenumber.ae;

/**
 * Carrier names — the idiomatic Java surface over the shared Aether engine's
 * {@code PhoneNumberToCarrierMapper} side-library (ABI v5).
 *
 * <p>A longest-prefix match over the number's E.164 digits. Every call takes a
 * raw {@code (region, input)}; the engine parses to E.164 internally. English
 * names only; {@code ""} means no carrier is known for the number.
 *
 * <pre>{@code
 * Carrier.carrierNameForNumber("GB", "7106000000");        // "O2"
 * Carrier.carrierNameForValidNumber("GB", "7106000000");   // "O2" (only if valid)
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
        Native a = api();
        return a.call2s(a.carrierName, region, input);
    }

    /** The carrier name only when the number is valid, else {@code ""}. */
    public static String carrierNameForValidNumber(String region, String input) {
        Native a = api();
        return a.call2s(a.carrierNameForValid, region, input);
    }
}
