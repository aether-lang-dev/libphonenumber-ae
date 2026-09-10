package org.libphonenumber.ae;

/**
 * The result of {@code isNumberMatch}, over the ABI's bare {@code int} (mirrors
 * {@code PhoneNumberUtil.MatchType}). Ordered by strictness: {@link #EXACT} is
 * the strongest agreement, {@link #NO_MATCH} the absence of one, and
 * {@link #NOT_A_NUMBER} means an input could not be parsed at all.
 */
public enum MatchType {
    NOT_A_NUMBER(Native.MATCH_NOT_A_NUMBER),
    NO_MATCH(Native.MATCH_NO_MATCH),
    SHORT_NSN_MATCH(Native.MATCH_SHORT_NSN),
    NSN_MATCH(Native.MATCH_NSN),
    EXACT_MATCH(Native.MATCH_EXACT);

    private final int code;

    MatchType(int code) {
        this.code = code;
    }

    /** The ABI integer for this match type. */
    public int code() {
        return code;
    }

    /** The {@link MatchType} for an ABI code, or {@link #NOT_A_NUMBER} if unrecognised. */
    public static MatchType of(int code) {
        for (MatchType m : values()) {
            if (m.code == code) return m;
        }
        return NOT_A_NUMBER;
    }
}
