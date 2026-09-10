package org.libphonenumber.ae;

/**
 * How strict {@link Matcher} is when it accepts a candidate found in free text,
 * over the ABI's bare {@code int} (mirrors {@code PhoneNumberUtil.Leniency}, at
 * the two levels the ABI exposes).
 *
 * <ul>
 *   <li>{@link #POSSIBLE} — accept anything of a possible length.</li>
 *   <li>{@link #VALID} — accept only numbers that are valid for a region.</li>
 * </ul>
 */
public enum Leniency {
    POSSIBLE(Native.LENIENCY_POSSIBLE),
    VALID(Native.LENIENCY_VALID);

    private final int code;

    Leniency(int code) {
        this.code = code;
    }

    /** The ABI integer for this leniency level. */
    public int code() {
        return code;
    }
}
