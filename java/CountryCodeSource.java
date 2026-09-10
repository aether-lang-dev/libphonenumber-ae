package org.libphonenumber.ae;

/**
 * How the country code of a parsed number was determined, over the ABI's bare
 * {@code int} result of {@code pn_source} (mirrors
 * {@code PhoneNumber.CountryCodeSource}).
 */
public enum CountryCodeSource {
    FROM_NUMBER_WITH_PLUS(Native.SRC_FROM_NUMBER_WITH_PLUS),
    FROM_NUMBER_WITH_IDD(Native.SRC_FROM_NUMBER_WITH_IDD),
    FROM_NUMBER_WITHOUT_PLUS_SIGN(Native.SRC_FROM_NUMBER_WITHOUT_PLUS),
    FROM_DEFAULT_COUNTRY(Native.SRC_FROM_DEFAULT_COUNTRY);

    private final int code;

    CountryCodeSource(int code) {
        this.code = code;
    }

    /** The ABI integer for this source. */
    public int code() {
        return code;
    }

    /** The {@link CountryCodeSource} for an ABI code, or {@code null} if unrecognised. */
    public static CountryCodeSource of(int code) {
        for (CountryCodeSource s : values()) {
            if (s.code == code) return s;
        }
        return null;
    }
}
