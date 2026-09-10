package org.libphonenumber.ae;

/**
 * Formats a phone number as it is typed, digit by digit (mirrors
 * {@code AsYouTypeFormatter}).
 *
 * <pre>{@code
 * AsYouTypeFormatter f = new AsYouTypeFormatter("US");
 * String out = "";
 * for (char c : "2015550123".toCharArray()) out = f.inputDigit(c);
 * // out == "(201) 555-0123"
 * }</pre>
 *
 * <p>This ABI has no opaque handles: the formatter state is itself a
 * caller-owned <em>string</em>, threaded through the {@code ayt_*} calls.
 * {@code ayt_input} returns a NEW state and the old one is freed by
 * {@link Native#takeString}, so this object simply keeps the latest state
 * string. Not thread-safe (the state is mutable), like the upstream class.
 */
public final class AsYouTypeFormatter {

    private String state;

    /** A new formatter for the given dialling region. */
    public AsYouTypeFormatter(String region) {
        Native a = api();
        this.state = a.call1s(a.aytNew, region);
    }

    private static Native api() {
        return Native.load(null);
    }

    /** Feed one character; returns the formatted-so-far string. */
    public String inputDigit(char ch) {
        return inputDigit(String.valueOf(ch));
    }

    /** Feed one character (as a one-char string); returns the formatted-so-far string. */
    public String inputDigit(String ch) {
        Native a = api();
        this.state = a.call2s(a.aytInput, state, ch);
        return result();
    }

    /** The number formatted so far. */
    public String result() {
        Native a = api();
        return a.call1s(a.aytResult, state);
    }

    /** Reset the formatter, discarding everything typed so far. */
    public void clear() {
        Native a = api();
        this.state = a.call1s(a.aytClear, state);
    }
}
