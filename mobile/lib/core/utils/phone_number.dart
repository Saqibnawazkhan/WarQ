/// Phone number normalisation for messaging deep links.
///
/// WhatsApp's `wa.me` links take a number in international format with no `+`,
/// spaces or punctuation — `+92 300 111 2222` must become `923001112222`.
/// Teachers, however, type numbers however they like, so everything is
/// normalised at the point of use rather than at entry (the spec keeps phone
/// fields optional and free-form).
class PhoneNumber {
  const PhoneNumber._();

  /// Digits only, in international format, ready for a `wa.me` link.
  ///
  /// Handles the three ways a number is realistically stored:
  ///  * `+923001112222` / `0092...` — already international;
  ///  * `03001112222` — national format with a trunk `0`, which is replaced by
  ///    [defaultCountryCode] when one is configured;
  ///  * `3001112222` — bare national number, prefixed with the country code.
  ///
  /// Returns `null` when the result cannot be a valid international number, so
  /// callers can skip the recipient instead of opening WhatsApp on a number
  /// that will not resolve.
  static String? toWhatsAppNumber(String? raw, {String? defaultCountryCode}) {
    if (raw == null) return null;

    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final bool hasPlus = trimmed.startsWith('+');
    String digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    final String? code = _normaliseCountryCode(defaultCountryCode);

    if (hasPlus) {
      // Already international.
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      // National format: swap the trunk prefix for the country code.
      if (code == null) return null;
      digits = '$code${digits.substring(1)}';
    } else if (code != null && !digits.startsWith(code)) {
      // A bare national number, e.g. "3001112222".
      digits = '$code$digits';
    }

    // E.164 allows at most 15 digits; anything under 8 cannot be a real
    // international number.
    if (digits.length < 8 || digits.length > 15) return null;
    return digits;
  }

  /// True when [raw] can be turned into a WhatsApp-addressable number.
  static bool isReachable(String? raw, {String? defaultCountryCode}) =>
      toWhatsAppNumber(raw, defaultCountryCode: defaultCountryCode) != null;

  /// `+923001112222` — for display and for `sms:` links.
  static String? toE164(String? raw, {String? defaultCountryCode}) {
    final String? digits =
        toWhatsAppNumber(raw, defaultCountryCode: defaultCountryCode);
    return digits == null ? null : '+$digits';
  }

  /// Accepts `92`, `+92` or `0092` and returns `92`.
  static String? _normaliseCountryCode(String? value) {
    if (value == null) return null;
    String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.isEmpty || digits.length > 4) return null;
    return digits;
  }

  /// Validates a dialling code entered in settings.
  static bool isValidCountryCode(String value) =>
      _normaliseCountryCode(value) != null;

  static String? normaliseCountryCode(String? value) =>
      _normaliseCountryCode(value);
}
