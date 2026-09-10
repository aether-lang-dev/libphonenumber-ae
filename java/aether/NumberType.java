package org.libphonenumber.ae;

/**
 * The kind of a phone number, over the ABI's bare {@code int} result of
 * {@code number_type}.
 *
 * <p>{@link #UNKNOWN} maps the ABI's {@code -1} <em>and</em> serves as the
 * fallback in {@link #of(int)}, so a newer engine that adds a type code cannot
 * make this binding throw — the ABI's type constants are append-only.
 */
public enum NumberType {
    UNKNOWN(Native.TYPE_UNKNOWN),
    FIXED_LINE(Native.TYPE_FIXED_LINE),
    MOBILE(Native.TYPE_MOBILE),
    TOLL_FREE(Native.TYPE_TOLL_FREE),
    PREMIUM_RATE(Native.TYPE_PREMIUM_RATE),
    SHARED_COST(Native.TYPE_SHARED_COST),
    VOIP(Native.TYPE_VOIP),
    PERSONAL_NUMBER(Native.TYPE_PERSONAL_NUMBER),
    PAGER(Native.TYPE_PAGER),
    UAN(Native.TYPE_UAN),
    VOICEMAIL(Native.TYPE_VOICEMAIL);

    private final int code;

    NumberType(int code) {
        this.code = code;
    }

    /** The ABI integer for this type. */
    public int code() {
        return code;
    }

    /**
     * The {@link NumberType} for an ABI code, or {@link #UNKNOWN} for a code
     * this build does not recognise (a newer engine, not an error).
     */
    public static NumberType of(int code) {
        for (NumberType t : values()) {
            if (t.code == code) return t;
        }
        return UNKNOWN;
    }
}
