package org.libphonenumber.ae;

/**
 * Short and emergency numbers — the idiomatic Java surface over the shared
 * Aether engine's {@code ShortNumberInfo} side-library (ABI v3).
 *
 * <p>Short numbers (emergency, directory, premium SMS, …) are dialled as-is:
 * no country calling code and no national prefix. Every call here takes the raw
 * short number plus its ISO-3166 region.
 *
 * <pre>{@code
 * ShortNumberInfo.isEmergencyNumber("US", "911");       // true
 * ShortNumberInfo.isValidShortNumber("US", "911");      // true
 * ShortNumberInfo.expectedCost("US", "911");            // ShortNumberCost.TOLL_FREE
 * ShortNumberInfo.exampleNumber("US");                  // "112"
 * }</pre>
 *
 * <p>Carries <b>no phone-number logic</b>: every method marshals to an
 * {@code aether_pn_embed_short_*} call in {@link Native}. All methods are static
 * and stateless; the engine is loaded lazily and cached via {@link Native#load}.
 *
 * <p>Requires {@code --enable-native-access=ALL-UNNAMED} on the command line.
 */
public final class ShortNumberInfo {

    private ShortNumberInfo() {
    }

    private static Native api() {
        return Native.load(null);
    }

    /** True if the input is a possible short number for the region (length only). */
    public static boolean isPossibleShortNumber(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortIsPossible, region, input) != 0;
    }

    /** True if the input is a valid short number for the region. */
    public static boolean isValidShortNumber(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortIsValid, region, input) != 0;
    }

    /** True if the input is an emergency number for the region. */
    public static boolean isEmergencyNumber(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortIsEmergency, region, input) != 0;
    }

    /** True if dialling the input in the region connects to an emergency service. */
    public static boolean connectsToEmergencyNumber(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortConnectsToEmergency, region, input) != 0;
    }

    /** True if the short number is carrier-specific for the region. */
    public static boolean isCarrierSpecific(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortIsCarrierSpecific, region, input) != 0;
    }

    /** True if the short number is an SMS service for the region. */
    public static boolean isSmsService(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortIsSmsService, region, input) != 0;
    }

    /** The expected cost of the short number as an ABI int ({@code 3} for unknown). */
    public static int expectedCostCode(String region, String input) {
        Native a = api();
        return a.calli2s(a.shortExpectedCost, region, input);
    }

    /** The expected cost of the short number as a {@link ShortNumberCost}. */
    public static ShortNumberCost expectedCost(String region, String input) {
        return ShortNumberCost.of(expectedCostCode(region, input));
    }

    /** An example short number for the region, or {@code ""}. */
    public static String exampleNumber(String region) {
        Native a = api();
        return a.call1s(a.shortExampleNumber, region);
    }
}
