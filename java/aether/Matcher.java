package org.libphonenumber.ae;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Finds phone numbers embedded in free text (mirrors
 * {@code PhoneNumberMatcher}).
 *
 * <pre>{@code
 * for (Matcher.Match m : Matcher.find("call 201-555-0123 today", "US")) {
 *     m.start();  // 5
 *     m.raw();    // "201-555-0123"
 * }
 * }</pre>
 *
 * <p>Each ABI matcher call ({@code matcher_count}/{@code _start}/{@code _end}/
 * {@code _raw}) re-scans the text independently — there is no handle — so
 * {@link #find} materialises the whole result set once, into an immutable list
 * of {@link Match}.
 */
public final class Matcher {

    private Matcher() {
    }

    /** One phone number found in the text: its {@code [start, end)} span and raw substring. */
    public static final class Match {
        private final int start;
        private final int end;
        private final String raw;

        Match(int start, int end, String raw) {
            this.start = start;
            this.end = end;
            this.raw = raw;
        }

        /** Start offset of the match in the source text. */
        public int start() {
            return start;
        }

        /** End offset (exclusive) of the match in the source text. */
        public int end() {
            return end;
        }

        /** The matched substring exactly as it appeared. */
        public String raw() {
            return raw;
        }

        @Override
        public String toString() {
            return "Match[" + start + "," + end + ")='" + raw + "'";
        }
    }

    /** Find phone numbers in {@code text} using {@link Leniency#VALID}. */
    public static List<Match> find(String text, String region) {
        return find(text, region, Leniency.VALID);
    }

    /** Find phone numbers in {@code text} at the given leniency. */
    public static List<Match> find(String text, String region, Leniency leniency) {
        Native a = api();
        int n = a.calli2s1i(a.matcherCount, text, region, leniency.code());
        List<Match> out = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            int start = a.calli2s2i(a.matcherStart, text, region, leniency.code(), i);
            int end = a.calli2s2i(a.matcherEnd, text, region, leniency.code(), i);
            String raw = a.call2s2i(a.matcherRaw, text, region, leniency.code(), i);
            out.add(new Match(start, end, raw));
        }
        return Collections.unmodifiableList(out);
    }

    private static Native api() {
        return Native.load(null);
    }
}
