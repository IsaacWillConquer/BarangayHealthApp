/// Shared input rules.
///
/// The web portal and the mobile app must reject the same input, otherwise a
/// resident can be told a form is invalid on one client and valid on the other.
/// These constants mirror `src/api/profileLocal.js` and
/// `src/components/ResidentFormModal.jsx`.
library;

const _kPhonePattern = r'^\d{11}$';
final _phonePattern = RegExp(_kPhonePattern);

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const civilStatuses = ['Single', 'Married', 'Widowed', 'Separated', 'Divorced'];
const genders = ['Male', 'Female', 'Other'];

/// Exactly 11 digits, matching the web app's `validatePhones`.
String? phoneError(String? value, String label, {bool required = true}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? '$label is required.' : null;
  if (!_phonePattern.hasMatch(text)) return '$label must be exactly 11 digits.';
  return null;
}

/// Optional field, so only validates when something was typed.
String? optionalPhoneError(String? value, String label) =>
    phoneError(value, label, required: false);

String? emailError(String? value, {bool required = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return required ? 'Email address is required.' : null;
  if (!_emailPattern.hasMatch(text)) return 'Email address is not valid.';
  return null;
}

String? requiredError(String? value) =>
    (value == null || value.trim().isEmpty) ? 'This field is required.' : null;

/// Local calendar date as `YYYY-MM-DD`, the format stored by the web app.
///
/// Deliberately not `toIso8601String()`, which would shift the day for anyone
/// east or west of UTC.
String todayString() {
  final now = DateTime.now();
  return formatDate(now);
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Lexical comparison is correct for zero-padded `YYYY-MM-DD` strings and
/// avoids timezone bugs entirely.
bool isFutureDate(String yyyyMmDd) => yyyyMmDd.compareTo(todayString()) > 0;

bool isTooOldDate(String yyyyMmDd, {int maxYears = 120}) {
  final year = int.tryParse(yyyyMmDd.split('-').first);
  return year != null && year < DateTime.now().year - maxYears;
}

/// Age in whole years, accounting for whether the birthday has passed.
int? ageFromBirthday(String? birthday) {
  if (birthday == null || birthday.isEmpty) return null;
  final parsed = DateTime.tryParse(birthday);
  if (parsed == null) return null;

  final now = DateTime.now();
  var age = now.year - parsed.year;
  final hadBirthday =
      now.month > parsed.month ||
      (now.month == parsed.month && now.day >= parsed.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? null : age;
}
