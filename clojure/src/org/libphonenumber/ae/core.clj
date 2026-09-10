(ns org.libphonenumber.ae.core
  "Idiomatic Clojure over the Java binding (ABI v6, full PhoneNumberUtil parity
  plus ShortNumberInfo, the timezone mapper, the carrier mapper and the offline
  geocoder).

  There is **no second FFI here**. The one JVM binding to the shared Aether
  engine is `java/aether/` (FFM / Panama), and everything in this namespace is
  ordinary Clojure/Java interop on top of those classes. A Clojure-specific FFI
  would be a second copy of the ABI's marshalling and ownership rules to keep in
  step with `core/embed.ae`, and the first thing to drift.

  What Clojure adds, and all it adds:

    * plain functions over the static Java methods, so they compose and thread;
    * `regions` / `regions-for-country-code` / `find-numbers` return Clojure
      vectors of plain data;
    * `number-type`, `format-style`, `validation-result`, `match-type` and
      `source` translate between keywords and the Java enums, so a caller need
      never import them. Each degrades to a fallback rather than throwing on a
      code this build does not know — the ABI's constants are append-only;
    * `parse` yields a plain map of the parsed fields.

  The engine carries the logic; this namespace carries none."
  (:import (org.libphonenumber.ae AsYouTypeFormatter
                                  Carrier
                                  CountryCodeSource
                                  Format
                                  Geocoder
                                  Leniency
                                  MatchType
                                  Matcher$Match
                                  NumberType
                                  ParsedNumber
                                  PhoneNumbers
                                  ShortNumberCost
                                  ShortNumberInfo
                                  TimeZones
                                  ValidationResult)))

(set! *warn-on-reflection* true)

;; ---- enum <-> keyword ----------------------------------------------------
;;
;; Maps with explicit fallbacks, not a case, because the ABI's constants are
;; append-only: a newer engine may return a value this build has never seen, and
;; that must become a fallback keyword rather than blow up.

(def ^:private type->kw
  {NumberType/FIXED_LINE      :fixed-line
   NumberType/MOBILE          :mobile
   NumberType/TOLL_FREE       :toll-free
   NumberType/PREMIUM_RATE    :premium-rate
   NumberType/SHARED_COST     :shared-cost
   NumberType/VOIP            :voip
   NumberType/PERSONAL_NUMBER :personal-number
   NumberType/PAGER           :pager
   NumberType/UAN             :uan
   NumberType/VOICEMAIL       :voicemail
   NumberType/FIXED_LINE_OR_MOBILE :fixed-line-or-mobile
   NumberType/UNKNOWN         :unknown})

(def ^:private kw->type
  (into {} (map (fn [[k v]] [v k]) type->kw)))

(def ^:private kw->format
  {:e164          Format/E164
   :international  Format/INTERNATIONAL
   :national      Format/NATIONAL
   :rfc3966       Format/RFC3966})

(def ^:private result->kw
  {ValidationResult/IS_POSSIBLE            :is-possible
   ValidationResult/IS_POSSIBLE_LOCAL_ONLY :is-possible-local-only
   ValidationResult/INVALID_COUNTRY_CODE   :invalid-country-code
   ValidationResult/TOO_SHORT              :too-short
   ValidationResult/INVALID_LENGTH         :invalid-length
   ValidationResult/TOO_LONG               :too-long})

(def ^:private match->kw
  {MatchType/NOT_A_NUMBER :not-a-number
   MatchType/NO_MATCH     :no-match
   MatchType/SHORT_NSN_MATCH :short-nsn
   MatchType/NSN_MATCH    :nsn
   MatchType/EXACT_MATCH  :exact})

(def ^:private source->kw
  {CountryCodeSource/FROM_NUMBER_WITH_PLUS         :from-number-with-plus
   CountryCodeSource/FROM_NUMBER_WITH_IDD          :from-number-with-idd
   CountryCodeSource/FROM_NUMBER_WITHOUT_PLUS_SIGN :from-number-without-plus
   CountryCodeSource/FROM_DEFAULT_COUNTRY          :from-default-country})

(def ^:private kw->leniency
  {:possible Leniency/POSSIBLE
   :valid    Leniency/VALID})

(def ^:private cost->kw
  {ShortNumberCost/TOLL_FREE     :toll-free
   ShortNumberCost/STANDARD_RATE :standard-rate
   ShortNumberCost/PREMIUM_RATE  :premium-rate
   ShortNumberCost/UNKNOWN       :unknown})

;; ---- metadata ------------------------------------------------------------

(defn country-code
  "The country calling code for a region (\"1\", \"44\", …), or \"\" if unknown."
  [^String region]
  (PhoneNumbers/countryCode region))

(defn example-number
  "An example national number for the region, or \"\"."
  [^String region]
  (PhoneNumbers/exampleNumber region))

(defn example-number-for-type
  "An example number of `type` (a keyword like :mobile) for the region, or \"\"."
  [^String region type]
  (PhoneNumbers/exampleNumberForType region ^NumberType (get kw->type type NumberType/UNKNOWN)))

(defn invalid-example-number
  "An example number that is deliberately invalid for the region, or \"\"."
  [^String region]
  (PhoneNumbers/invalidExampleNumber region))

(defn possible-lengths
  "The possible-lengths spec for the region (e.g. \"10\"), or \"\"."
  [^String region]
  (PhoneNumbers/possibleLengths region))

(defn region-code-for-country-code
  "The main region for a country calling code (\"GB\" for \"44\"), or \"\"."
  [^String cc]
  (PhoneNumbers/regionCodeForCountryCode cc))

(defn nanpa-country?
  "True if the region belongs to the North American Numbering Plan."
  [^String region]
  (PhoneNumbers/isNanpaCountry region))

(defn ndd-prefix-for-region
  "The national-direct-dialling prefix for the region, or \"\"."
  ([^String region] (ndd-prefix-for-region region false))
  ([^String region strip-non-digits]
   (PhoneNumbers/nddPrefixForRegion region (boolean strip-non-digits))))

(defn regions
  "Every region id the metadata carries, as a vector of ISO-3166 codes."
  []
  (vec (PhoneNumbers/regions)))

(defn regions-for-country-code
  "The regions served by a country calling code, main region first, as a vector."
  [^String cc]
  (vec (PhoneNumbers/regionsForCountryCode cc)))

;; ---- parse ---------------------------------------------------------------

(defn parse
  "Parse raw `input` in `region` into a plain map of the number's fields:
  :region :country-code :national-number :extension :italian-leading-zero
  :source :error :region-code :national-significant-number
  :length-of-ndc :length-of-area-code :geographical. `:error` is non-empty if
  the parse failed."
  [^String input ^String region]
  (let [^ParsedNumber p (PhoneNumbers/parse input region)]
    {:region                      (.region p)
     :country-code                (.countryCode p)
     :national-number             (.nationalNumber p)
     :extension                   (.extension p)
     :italian-leading-zero        (.italianLeadingZero p)
     :source                      (get source->kw (.source p) :unknown)
     :error                       (.error p)
     :region-code                 (.regionCode p)
     :national-significant-number (.nationalSignificantNumber p)
     :length-of-ndc               (.lengthOfNationalDestinationCode p)
     :length-of-area-code         (.lengthOfAreaCode p)
     :geographical                (.isGeographical p)}))

(defn national-number
  "The national number extracted from raw input (cc + punctuation stripped)."
  [^String region ^String input]
  (PhoneNumbers/nationalNumber region input))

;; ---- validation ----------------------------------------------------------

(defn possible-number?
  "True if the national number is a length the region allows."
  [^String region ^String input]
  (PhoneNumbers/isPossibleNumber region input))

(defn possible-number-reason
  "Why (or why not) the number is possible, as a keyword: :is-possible,
  :is-possible-local-only, :invalid-country-code, :too-short, :invalid-length,
  :too-long, or :unknown."
  [^String region ^String input]
  (get result->kw (PhoneNumbers/isPossibleNumberWithReason region input) :unknown))

(defn valid-number?
  "True if the number matches the region's national-number patterns."
  [^String region ^String input]
  (PhoneNumbers/isValidNumber region input))

(defn valid-number-for-region?
  "True if the number is valid AND belongs to the region. Arg order: input, region."
  [^String input ^String region]
  (PhoneNumbers/isValidNumberForRegion input region))

(defn number-type
  "The number's type as a keyword: `:fixed-line`, `:mobile`, `:toll-free`,
  `:premium-rate`, `:shared-cost`, `:voip`, `:personal-number`, `:pager`,
  `:uan`, `:voicemail`, `:fixed-line-or-mobile`, or `:unknown`."
  [^String region ^String input]
  (get type->kw (PhoneNumbers/numberType region input) :unknown))

(defn internationally-dialled?
  "True if the number can be dialled from outside its country."
  [^String region ^String input]
  (PhoneNumbers/canBeInternationallyDialled region input))

;; ---- formatting ----------------------------------------------------------

(defn format-number
  "Format the number in `style` — a keyword `:national` (default),
  `:international`, `:e164` or `:rfc3966`. An unknown style falls back to
  `:national`."
  ([^String region ^String input] (format-number region input :national))
  ([^String region ^String input style]
   (PhoneNumbers/format region input ^Format (get kw->format style Format/NATIONAL))))

(defn format-national [^String region ^String input]
  (PhoneNumbers/formatNational region input))

(defn format-international [^String region ^String input]
  (PhoneNumbers/formatInternational region input))

(defn format-e164 [^String region ^String input]
  (PhoneNumbers/formatE164 region input))

(defn format-rfc3966 [^String region ^String input]
  (PhoneNumbers/formatRfc3966 region input))

(defn format-out-of-country
  "Format `input` (of `region`) as dialled from `calling-from`."
  [^String region ^String input ^String calling-from]
  (PhoneNumbers/formatOutOfCountry region input calling-from))

;; ---- relations / helpers -------------------------------------------------

(defn number-match
  "How well two numbers match, as a keyword: :not-a-number, :no-match,
  :short-nsn, :nsn or :exact."
  [^String a ^String b]
  (get match->kw (PhoneNumbers/isNumberMatch a b) :not-a-number))

(defn truncate-too-long
  "Trim a too-long number down to a possible length for the region."
  [^String region ^String input]
  (PhoneNumbers/truncateTooLong region input))

(defn normalize-digits-only
  "Strip everything but the digits."
  [^String s]
  (PhoneNumbers/normalizeDigitsOnly s))

(defn convert-alpha-characters
  "Convert vanity letters to their dial-pad digits."
  [^String s]
  (PhoneNumbers/convertAlphaCharacters s))

(defn alpha-number?
  "True if the input contains vanity letters."
  [^String s]
  (PhoneNumbers/isAlphaNumber s))

;; ---- as-you-type ---------------------------------------------------------

(defn as-you-type
  "Feed `input` (a string) into a fresh AsYouTypeFormatter for `region`, one
  char at a time, and return the formatted-so-far result."
  [^String region ^String input]
  (let [f (AsYouTypeFormatter. region)]
    (reduce (fn [_ ^Character c] (.inputDigit f (char c))) "" input)))

;; ---- find numbers --------------------------------------------------------

(defn find-numbers
  "Find phone numbers in free text. Returns a vector of maps
  {:start int :end int :raw string}. `leniency` is `:valid` (default) or
  `:possible`."
  ([^String text ^String region] (find-numbers text region :valid))
  ([^String text ^String region leniency]
   (mapv (fn [^Matcher$Match m]
           {:start (.start m) :end (.end m) :raw (.raw m)})
         (PhoneNumbers/findNumbers text region
                                   ^Leniency (get kw->leniency leniency Leniency/VALID)))))

;; ---- short numbers -------------------------------------------------------
;;
;; Short numbers (emergency, directory, premium SMS, …) are dialled as-is: no
;; country code and no national prefix. These reach the Java ShortNumberInfo.

(defn possible-short-number?
  "True if `input` is a possible short number for `region` (length only)."
  [^String region ^String input]
  (ShortNumberInfo/isPossibleShortNumber region input))

(defn valid-short-number?
  "True if `input` is a valid short number for `region`."
  [^String region ^String input]
  (ShortNumberInfo/isValidShortNumber region input))

(defn emergency-number?
  "True if `input` is an emergency number for `region`."
  [^String region ^String input]
  (ShortNumberInfo/isEmergencyNumber region input))

(defn connects-to-emergency-number?
  "True if dialling `input` in `region` connects to an emergency service."
  [^String region ^String input]
  (ShortNumberInfo/connectsToEmergencyNumber region input))

(defn carrier-specific?
  "True if the short number is carrier-specific for `region`."
  [^String region ^String input]
  (ShortNumberInfo/isCarrierSpecific region input))

(defn sms-service?
  "True if the short number is an SMS service for `region`."
  [^String region ^String input]
  (ShortNumberInfo/isSmsService region input))

(defn short-expected-cost
  "The expected cost of the short number, as a keyword: `:toll-free`,
  `:standard-rate`, `:premium-rate` or `:unknown`."
  [^String region ^String input]
  (get cost->kw (ShortNumberInfo/expectedCost region input) :unknown))

(defn short-example-number
  "An example short number for `region`, or \"\"."
  [^String region]
  (ShortNumberInfo/exampleNumber region))

;; ---- timezones -----------------------------------------------------------
;;
;; A longest-prefix match over the number's E.164 digits. These reach the Java
;; TimeZones mapper.

(defn time-zones-for-number
  "The IANA timezone ids for a number, as a vector. A number with no known zone
  maps to a single-element vector of the unknown zone (\"Etc/Unknown\")."
  [^String region ^String input]
  (vec (TimeZones/timeZonesForNumber region input)))

(defn time-zone-count
  "The number of zones for the number (0 = only the unknown zone)."
  [^String region ^String input]
  (TimeZones/timeZoneCount region input))

(defn unknown-time-zone
  "The unknown-zone sentinel, \"Etc/Unknown\"."
  []
  (TimeZones/unknownTimeZone))

;; ---- carrier -------------------------------------------------------------
;;
;; English carrier names by longest-prefix match over the E.164 digits. These
;; reach the Java Carrier mapper.

(defn carrier-name-for-number
  "The carrier name for a number (English), or \"\" if none is known."
  [^String region ^String input]
  (Carrier/carrierNameForNumber region input))

(defn carrier-name-for-valid-number
  "The carrier name only when the number is valid, else \"\"."
  [^String region ^String input]
  (Carrier/carrierNameForValidNumber region input))

;; ---- geocoder ------------------------------------------------------------
;;
;; English geographic descriptions by longest-prefix match over the E.164
;; digits. These reach the Java Geocoder mapper.

(defn geo-description-for-number
  "A geographic description for a number (English), or \"\" if none is known."
  [^String region ^String input]
  (Geocoder/geoDescriptionForNumber region input))

(defn geo-description-for-valid-number
  "A geographic description only when the number is valid, else \"\"."
  [^String region ^String input]
  (Geocoder/geoDescriptionForValidNumber region input))

;; ---- version -------------------------------------------------------------

(defn abi-version
  "The ABI revision the loaded engine reports (6 for this build)."
  []
  (PhoneNumbers/abiVersion))
