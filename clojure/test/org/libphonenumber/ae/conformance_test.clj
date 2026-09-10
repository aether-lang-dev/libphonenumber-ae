(ns org.libphonenumber.ae.conformance-test
  "The 40-check binding conformance suite (docs/conformance.md, v3), in Clojure.

  Proves the **Clojure layer** reaches the same engine behaviour the Java and
  Python suites see. Since that layer sits on the Java binding rather than on
  its own FFI, what this really pins down is that the Clojure wrapping — the
  keyword <-> enum translation, the vector coercion of `regions`/`find-numbers`,
  the plain-map `parse` — marshals every value shape correctly.

  It is NOT a phone-number test suite — the behavioural cases live in the
  engine's own tests and run once, in Aether.

  `clojure.test` rather than an external framework, so the run needs nothing but
  the Clojure jar itself: it works offline and cannot fail resolving a
  test-framework artifact."
  (:require [clojure.test :refer [deftest is run-tests]]
            [org.libphonenumber.ae.core :as pn]))

;; ---- the 40 required checks ----------------------------------------------

(deftest test-01-country-code-us
  (is (= "1" (pn/country-code "US"))))

(deftest test-02-country-code-gb
  (is (= "44" (pn/country-code "GB"))))

(deftest test-03-unknown-region
  (is (= "" (pn/country-code "ZZ"))))

(deftest test-04-example-number
  (is (= "2015550123" (pn/example-number "US"))))

(deftest test-05-possible-lengths
  (is (= "10" (pn/possible-lengths "US"))))

(deftest test-06-region-code-for-country-code
  (is (= "GB" (pn/region-code-for-country-code "44"))))

(deftest test-07-nanpa-country
  (is (true? (pn/nanpa-country? "US"))))

(deftest test-08-region-enumeration
  (let [regs (pn/regions)]
    (is (>= (count regs) 200))
    (is (= 2 (count (first regs))))))

(deftest test-09-regions-for-country-code
  (is (= "US" (first (pn/regions-for-country-code "1")))))

(deftest test-10-14-parse
  (let [p (pn/parse "+1 201 555 0123 ext 42" "US")]
    (is (= "" (:error p)))
    (is (= "2015550123" (:national-number p)))
    (is (= "42" (:extension p)))
    (is (= "1" (:country-code p)))
    (is (= :from-number-with-plus (:source p)))
    (is (= "US" (:region-code p)))))

(deftest test-15-parse-trunk-prefix
  (is (= "1212345678" (:national-number (pn/parse "01212345678" "GB")))))

(deftest test-16-is-possible
  (is (true? (pn/possible-number? "US" "2015550123"))))

(deftest test-17-reason-too-short
  (is (= :too-short (pn/possible-number-reason "US" "201555"))))

(deftest test-18-is-valid
  (is (true? (pn/valid-number? "US" "2015550123"))))

(deftest test-19-invalid-shape
  (is (false? (pn/valid-number? "US" "1015550123"))))

(deftest test-20-valid-with-cc
  (is (true? (pn/valid-number? "US" "+12015550123"))))

(deftest test-21-number-type
  ;; US fixedLine==mobile -> :fixed-line-or-mobile; GB has distinct patterns.
  (is (= :fixed-line-or-mobile (pn/number-type "US" "2015550123")))
  (is (= :fixed-line (pn/number-type "GB" "2070313000"))))

(deftest test-22-format-national
  (is (= "(201) 555-0123" (pn/format-number "US" "2015550123" :national))))

(deftest test-23-format-e164
  (is (= "+12015550123" (pn/format-number "US" "2015550123" :e164))))

(deftest test-24-format-international
  (is (= "+1 201-555-0123" (pn/format-number "US" "2015550123" :international))))

(deftest test-25-format-rfc3966
  (is (= "tel:+1-201-555-0123" (pn/format-number "US" "2015550123" :rfc3966))))

(deftest test-26-match-exact
  (is (= :exact (pn/number-match "+12015550123" "+1 201 555 0123"))))

(deftest test-27-match-none
  (is (= :no-match (pn/number-match "+12015550123" "+12025550123"))))

(deftest test-28-normalize
  (is (= "12015550123" (pn/normalize-digits-only "+1 (201) 555.0123"))))

(deftest test-29-alpha
  (is (= "1-800-3569377" (pn/convert-alpha-characters "1-800-FLOWERS"))))

(deftest test-30-truncate
  (is (= "2015550123" (pn/truncate-too-long "US" "20155501239999"))))

(deftest test-31-as-you-type
  (is (= "(201) 555-0123" (pn/as-you-type "US" "2015550123"))))

(deftest test-32-find-numbers-count
  (is (= 2 (count (pn/find-numbers "call 201-555-0123 or +1 202 555 0199" "US" :valid)))))

(deftest test-33-find-numbers-raw
  (is (= "201-555-0123" (:raw (first (pn/find-numbers "call 201-555-0123 now" "US" :valid))))))

(deftest test-34-abi-version
  (is (= 3 (pn/abi-version))))

(deftest test-35-emergency-us-911
  (is (true? (pn/emergency-number? "US" "911"))))

(deftest test-36-not-emergency-us-999
  (is (false? (pn/emergency-number? "US" "999"))))

(deftest test-37-emergency-gb-999
  (is (true? (pn/emergency-number? "GB" "999"))))

(deftest test-38-valid-short-us-911
  (is (true? (pn/valid-short-number? "US" "911"))))

(deftest test-39-expected-cost-us-911
  (is (= :toll-free (pn/short-expected-cost "US" "911"))))

(deftest test-40-short-example-us
  (is (= "112" (pn/short-example-number "US"))))

;; ---- extras specific to the Clojure layer --------------------------------

(deftest test-format-default-style-is-national
  (is (= "(201) 555-0123" (pn/format-number "US" "2015550123"))))

(deftest test-format-helpers-agree
  (is (= "+12015550123" (pn/format-e164 "US" "2015550123")))
  (is (= "+1 201-555-0123" (pn/format-international "US" "2015550123")))
  (is (= "tel:+1-201-555-0123" (pn/format-rfc3966 "US" "2015550123")))
  (is (= "(201) 555-0123" (pn/format-national "US" "2015550123"))))

;; ---- runner --------------------------------------------------------------

(defn -main
  "Entry point for `clojure.main -m`, so the suite runs with nothing but the
  Clojure jar. Exits non-zero if anything failed, which is what the aeb node
  keys off."
  [& _args]
  (let [{:keys [fail error]} (run-tests 'org.libphonenumber.ae.conformance-test)]
    (shutdown-agents)
    (System/exit (if (pos? (+ fail error)) 1 0))))
