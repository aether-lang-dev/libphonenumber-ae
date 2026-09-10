package org.libphonenumber.ae;

/**
 * The outcome of {@code isPossibleNumberWithReason}, over the ABI's bare
 * {@code int} (mirrors {@code PhoneNumberUtil.ValidationResult}).
 *
 * <p>{@link #of(int)} falls back to {@link #IS_POSSIBLE}-free handling by
 * returning {@code null} for a code this build does not recognise; the ABI's
 * result codes are append-only, so a newer engine cannot make this binding
 * throw.
 */
public enum ValidationResult {
    IS_POSSIBLE(Native.VR_IS_POSSIBLE),
    IS_POSSIBLE_LOCAL_ONLY(Native.VR_IS_POSSIBLE_LOCAL_ONLY),
    INVALID_COUNTRY_CODE(Native.VR_INVALID_COUNTRY_CODE),
    TOO_SHORT(Native.VR_TOO_SHORT),
    INVALID_LENGTH(Native.VR_INVALID_LENGTH),
    TOO_LONG(Native.VR_TOO_LONG);

    private final int code;

    ValidationResult(int code) {
        this.code = code;
    }

    /** The ABI integer for this result. */
    public int code() {
        return code;
    }

    /** The {@link ValidationResult} for an ABI code, or {@code null} if unrecognised. */
    public static ValidationResult of(int code) {
        for (ValidationResult v : values()) {
            if (v.code == code) return v;
        }
        return null;
    }
}
