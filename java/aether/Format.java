package org.libphonenumber.ae;

/**
 * A phone-number presentation style, over the ABI's bare {@code int}.
 *
 * <ul>
 *   <li>{@link #E164} — e.g. {@code +12015550123} (ABI code {@code 0})</li>
 *   <li>{@link #INTERNATIONAL} — e.g. {@code +1 201-555-0123}</li>
 *   <li>{@link #NATIONAL} — e.g. {@code (201) 555-0123}</li>
 *   <li>{@link #RFC3966} — e.g. {@code tel:+1-201-555-0123}</li>
 * </ul>
 *
 * <p><b>ABI v2 note:</b> {@code E164} is now code {@code 0} (it was {@code 2}
 * under v1). The codes are append-only, so this enum never grows unexpectedly —
 * a new style would be a deliberate ABI revision.
 */
public enum Format {
    E164(Native.FMT_E164),
    INTERNATIONAL(Native.FMT_INTERNATIONAL),
    NATIONAL(Native.FMT_NATIONAL),
    RFC3966(Native.FMT_RFC3966);

    private final int code;

    Format(int code) {
        this.code = code;
    }

    /** The ABI integer this style marshals to. */
    public int code() {
        return code;
    }
}
