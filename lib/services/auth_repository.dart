import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/validators.dart';

const _kResidents = 'residents';
const _kCounters = 'counters';
const _kResidentNumberField = 'residentNumber';

const _inactiveResidentMessage =
    'This account is not active. Please visit or contact the Barangay Health Center office for assistance.';

class AuthResult {
  const AuthResult({
    required this.success,
    this.error,
    this.mustChangePassword = false,
  });

  final bool success;
  final String? error;
  final bool mustChangePassword;
}

class RegistrationResult {
  const RegistrationResult({
    required this.success,
    this.error,
    this.residentNumber,
  });

  final bool success;
  final String? error;
  final String? residentNumber;
}

/// Plaintext Firestore login, mirroring `src/api/authLocal.js`.
///
/// The web app queries by ResidentNumber first and falls back to Email. Staff
/// login is intentionally not wired up in the mobile app.
class AuthRepository {
  AuthRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    final id = identifier.trim();
    if (id.isEmpty || password.isEmpty) {
      return const AuthResult(
        success: false,
        error: 'Enter your Resident Number and password.',
      );
    }

    try {
      DocumentSnapshot<Map<String, dynamic>>? match;
      final byNumber = await _db
          .collection(_kResidents)
          .where('ResidentNumber', isEqualTo: id)
          .limit(1)
          .get();
      if (byNumber.docs.isNotEmpty) {
        match = byNumber.docs.first;
      } else {
        final byEmail = await _db
            .collection(_kResidents)
            .where('Email', isEqualTo: id.toLowerCase())
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) match = byEmail.docs.first;
      }

      if (match == null) {
        return const AuthResult(
          success: false,
          error: 'No resident account matches those details.',
        );
      }

      final data = match.data() ?? const <String, dynamic>{};
      final stored = (data['Password'] ?? '').toString();
      if (stored != password) {
        return const AuthResult(
          success: false,
          error: 'That password is incorrect.',
        );
      }

      final status = (data['Status'] ?? '').toString();
      if (status != 'Active') {
        return AuthResult(success: false, error: _inactiveResidentMessage);
      }

      return AuthResult(
        success: true,
        mustChangePassword: data['MustChangePassword'] == true,
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        error:
            'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  /// Re-reads the matched resident after a successful password check, so the
  /// caller can store the document id and name for the session.
  ///
  /// Returns null when nothing matches, which is the same lookup [login] used.
  Future<Map<String, dynamic>?> docForLogin(String identifier) async {
    final id = identifier.trim();
    if (id.isEmpty) return null;
    try {
      final byNumber = await _db
          .collection(_kResidents)
          .where('ResidentNumber', isEqualTo: id)
          .limit(1)
          .get();
      if (byNumber.docs.isNotEmpty) {
        final doc = byNumber.docs.first;
        return {...doc.data(), 'ResidentID': doc.id};
      }
      final byEmail = await _db
          .collection(_kResidents)
          .where('Email', isEqualTo: id.toLowerCase())
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty) {
        final doc = byEmail.docs.first;
        return {...doc.data(), 'ResidentID': doc.id};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResult> changePassword({
    required String residentId,
    required String newPassword,
  }) async {
    if (newPassword.length < 7) {
      return const AuthResult(
        success: false,
        error: 'Your new password must be at least 7 characters.',
      );
    }
    try {
      await _db.collection(_kResidents).doc(residentId).update({
        'Password': newPassword,
        'MustChangePassword': false,
      });
      return const AuthResult(success: true);
    } catch (_) {
      return const AuthResult(
        success: false,
        error: 'Could not update your password. Please try again.',
      );
    }
  }

  /// Allocates the next `RES-####` value inside a transaction so two
  /// simultaneous registrations can never receive the same number.
  Future<String> _nextResidentNumber() async {
    final counterRef = _db.collection(_kCounters).doc(_kResidentNumberField);
    return _db.runTransaction<String>((txn) async {
      final snap = await txn.get(counterRef);
      final next = ((snap.data()?['value'] as num?)?.toInt() ?? 1) + 1;
      txn.set(counterRef, {'value': next});
      return 'RES-${next.toString().padLeft(4, '0')}';
    });
  }

  /// Writes a self-registration as `Pending`.
  ///
  /// The document is created up front so the applicant can be told their
  /// Resident Number, but they cannot log in until staff approve it. The
  /// initial password equals the Resident Number and forces a change on first
  /// login. Rejected numbers are never reused, matching the web app.
  Future<RegistrationResult> register({
    required Map<String, dynamic> fields,
  }) async {
    // Re-checked here so a caller that skips the form's validators still cannot
    // write a malformed resident. Mirrors `createResident` in the web app.
    final problem = validateRegistration(fields);
    if (problem != null) {
      return RegistrationResult(success: false, error: problem);
    }

    final email = (fields['Email'] as String? ?? '').trim().toLowerCase();
    if (email.isNotEmpty && await _emailTaken(email)) {
      return const RegistrationResult(
        success: false,
        error:
            'That email address is already registered. Please use another one.',
      );
    }

    try {
      final residentNumber = await _nextResidentNumber();
      final docRef = _db.collection(_kResidents).doc();

      await docRef.set({
        ...fields,
        'ResidentNumber': residentNumber,
        'Status': 'Pending',
        'IsArchived': false,
        'Password': residentNumber,
        'MustChangePassword': true,
        'RegisteredAt': FieldValue.serverTimestamp(),
      });

      return RegistrationResult(success: true, residentNumber: residentNumber);
    } catch (_) {
      return const RegistrationResult(
        success: false,
        error: 'Could not submit your registration. Please try again.',
      );
    }
  }

  /// Guards the email fallback in [login]: two residents sharing one email
  /// would make sign-in ambiguous, so the second registration is refused.
  Future<bool> _emailTaken(String email) async {
    try {
      final snap = await _db
          .collection(_kResidents)
          .where('Email', isEqualTo: email)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      // Fail open rather than block a legitimate registration on a network blip.
      return false;
    }
  }

  /// Server-side mirror of the register form's rules.
  static String? validateRegistration(Map<String, dynamic> fields) {
    for (final key in [
      'FirstName',
      'LastName',
      'Birthday',
      'Address',
      'EmergencyContactName',
      'EmergencyContactRelationship',
    ]) {
      if (requiredError(fields[key] as String?) != null) {
        return 'Please complete every required field.';
      }
    }

    final email = emailError(fields['Email'] as String?);
    if (email != null) return email;

    for (final entry in {
      'ContactNumber': 'Contact number',
      'EmergencyContactNumber': 'Emergency contact number',
    }.entries) {
      final problem = phoneError(fields[entry.key] as String?, entry.value);
      if (problem != null) return problem;
    }

    final birthday = (fields['Birthday'] as String).trim();
    if (DateTime.tryParse(birthday) == null) return 'Birthday is not valid.';
    if (isFutureDate(birthday)) return 'Birthday cannot be in the future.';
    if (isTooOldDate(birthday)) {
      return 'Birthday is too far in the past — please check the year.';
    }

    if (!civilStatuses.contains(fields['CivilStatus'])) {
      return 'A valid civil status is required.';
    }
    if (!genders.contains(fields['Gender'])) {
      return 'A valid gender is required.';
    }
    return null;
  }

  /// Raises the shared counter if the project already has residents created
  /// outside this sequence, so the first auto-generated number never collides
  /// with a manually assigned `RES-####`.
  Future<void> ensureCounterAtLeast(int value) async {
    final counterRef = _db.collection(_kCounters).doc(_kResidentNumberField);
    try {
      await _db.runTransaction((txn) async {
        final snap = await txn.get(counterRef);
        final current = (snap.data()?['value'] as num?)?.toInt() ?? 0;
        if (current < value) txn.set(counterRef, {'value': value});
      });
    } catch (_) {
      // A missing or unreadable counter only risks a collision warning on the
      // Firebase console; it must not block the app from starting.
    }
  }
}
