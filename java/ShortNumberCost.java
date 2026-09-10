package org.libphonenumber.ae;

/**
 * The expected cost of dialling a short number, over the ABI's bare {@code int}
 * result of {@code short_expected_cost}.
 *
 * <p>{@link #UNKNOWN} maps the ABI's {@code 3} <em>and</em> serves as the
 * fallback in {@link #of(int)}, so a newer engine that adds a cost code cannot
 * make this binding throw — the ABI's cost constants are append-only.
 */
public enum ShortNumberCost {
    TOLL_FREE(Native.COST_TOLL_FREE),
    STANDARD_RATE(Native.COST_STANDARD_RATE),
    PREMIUM_RATE(Native.COST_PREMIUM_RATE),
    UNKNOWN(Native.COST_UNKNOWN);

    private final int code;

    ShortNumberCost(int code) {
        this.code = code;
    }

    /** The ABI integer for this cost. */
    public int code() {
        return code;
    }

    /**
     * The {@link ShortNumberCost} for an ABI code, or {@link #UNKNOWN} for a
     * code this build does not recognise (a newer engine, not an error).
     */
    public static ShortNumberCost of(int code) {
        for (ShortNumberCost c : values()) {
            if (c.code == code) return c;
        }
        return UNKNOWN;
    }
}
