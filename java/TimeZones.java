package org.libphonenumber.ae;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Timezone lookup — the idiomatic Java surface over the shared Aether engine's
 * {@code PhoneNumberToTimeZonesMapper} side-library (ABI v5).
 *
 * <p>A longest-prefix match over the number's E.164 digits. Every call takes a
 * raw {@code (region, input)} like the rest of the binding; the engine parses to
 * E.164 internally. The unknown-zone sentinel is {@code "Etc/Unknown"}.
 *
 * <pre>{@code
 * TimeZones.timeZonesForNumber("US", "2015550123");  // ["America/New_York"]
 * TimeZones.timeZonesForNumber("GB", "2070313000");  // ["Europe/London"]
 * TimeZones.unknownTimeZone();                       // "Etc/Unknown"
 * }</pre>
 *
 * <p>Carries <b>no phone-number logic</b>: every method marshals to an
 * {@code aether_pn_embed_tz_*} call in {@link Native}. All methods are static
 * and stateless; the engine is loaded lazily and cached via {@link Native#load}.
 *
 * <p>Requires {@code --enable-native-access=ALL-UNNAMED} on the command line.
 */
public final class TimeZones {

    private TimeZones() {
    }

    private static Native api() {
        return Native.load(null);
    }

    /**
     * The IANA timezone ids for a number, as a list. A number with no known
     * zone maps to a single-element list of {@link #unknownTimeZone()}.
     */
    public static List<String> timeZonesForNumber(String region, String input) {
        Native a = api();
        int n = a.calli2s(a.tzCount, region, input);
        if (n == 0) {
            return Collections.singletonList(unknownTimeZone());
        }
        List<String> out = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            out.add(a.call2s1i(a.tzAt, region, input, i));
        }
        return Collections.unmodifiableList(out);
    }

    /** The number of zones for the number ({@code 0} = only the unknown zone). */
    public static int timeZoneCount(String region, String input) {
        Native a = api();
        return a.calli2s(a.tzCount, region, input);
    }

    /** The unknown-zone sentinel, {@code "Etc/Unknown"}. */
    public static String unknownTimeZone() {
        Native a = api();
        try {
            return a.takeString(
                    (java.lang.foreign.MemorySegment) a.tzUnknown.invokeExact());
        } catch (Throwable t) {
            throw Native.wrap(t);
        }
    }
}
