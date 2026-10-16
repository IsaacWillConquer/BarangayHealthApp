import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/validators.dart';
import 'profile_image.dart';

/// Result shape shared by the profile and survey repositories.
class RepoResult {
  const RepoResult({required this.success, this.message});

  final bool success;
  final String? message;
}

/// Reads and writes the signed-in resident's own `residents` document.
///
/// Mirrors `src/api/profileLocal.js`, including its validation rules and its
/// strict merge list. `Password`, `Status`, `ResidentNumber`, `FirstName`, and
/// `LastName` are intentionally never written from here, so a profile edit can
/// not grant itself access or rewrite the identity the staff approved.
class ProfileRepository {
  ProfileRepository({required this.residentId, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final String residentId;
  final FirebaseFirestore _db;

  Map<String, dynamic>? _cache;

  Map<String, dynamic>? get cached => _cache;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('residents').doc(residentId);

  /// Live profile updates, so an edit on the web portal reflects in the app.
  ///
  /// Also refreshes [cached] on every event, which the dashboard reads from.
  Stream<Map<String, dynamic>> watch() {
    return _doc.snapshots().map((snap) {
      _cache = snap.data();
      return snap.data() ?? const <String, dynamic>{};
    });
  }

  /// One-shot reload for pull-to-refresh, which must not open a second
  /// long-lived subscription alongside [watch].
  Future<void> refresh() async {
    try {
      _cache = (await _doc.get()).data();
    } catch (_) {
      // Keep the last good value rather than blanking the screen.
    }
  }

  Future<RepoResult> update(Map<String, dynamic> f) async {
    final error = validate(f);
    if (error != null) return RepoResult(success: false, message: error);

    try {
      await _doc.update(buildUpdate(f));
      return const RepoResult(success: true);
    } catch (_) {
      return const RepoResult(
        success: false,
        message: "Couldn't save your profile. Check your connection.",
      );
    }
  }

  /// The exact set of fields a profile edit is allowed to write.
  ///
  /// `Password`, `Status`, `ResidentNumber`, `FirstName`, and `LastName` are
  /// intentionally absent so an edit can not grant itself access or rewrite the
  /// identity staff approved. Exposed as a pure function so that guarantee is
  /// asserted in tests without needing a Firestore instance.
  static Map<String, dynamic> buildUpdate(Map<String, dynamic> f) {
    final married = f['civilStatus'] == 'Married';

    final update = <String, dynamic>{
      'MiddleName': f['middleName'] ?? '',
      'ExtensionName': f['extensionName'] ?? '',
      'CivilStatus': f['civilStatus'],
      'Gender': f['gender'],
      'Birthday': f['birthday'],
      'Address': f['address'],
      'Address2': f['address2'] ?? '',
      'Email': f['email'] ?? '',
      'ContactNumber': f['contactNumber'],
      'HomePhone': f['homePhone'] ?? '',
      'EmergencyContactName': f['emergencyContactName'],
      'EmergencyContactRelationship': f['emergencyContactRelationship'],
      'EmergencyContactNumber': f['emergencyContactNumber'],
      'Bio': f['bio'] ?? '',
      'Occupation': f['occupation'] ?? '',
      'OccupationLocation': f['occupationLocation'] ?? '',
      'FatherName': f['fatherName'] ?? '',
      'MotherName': f['motherName'] ?? '',
      'Reference1Name': f['reference1Name'] ?? '',
      'Reference1Contact': f['reference1Contact'] ?? '',
      'Reference2Name': f['reference2Name'] ?? '',
      'Reference2Contact': f['reference2Contact'] ?? '',
      'Spouse': married
          ? {
              'Name': f['spouseName'],
              'Birthdate': f['spouseBirthdate'],
              'CivilStatus': f['spouseCivilStatus'],
              'Status': f['spouseStatus'] ?? 'Alive',
            }
          : null,
    };

    // Only written when the caller supplies one. The edit form submits every
    // field on every save, so defaulting this to '' would silently erase an
    // existing photo whenever an unrelated field changed. An empty string is
    // the explicit "remove my photo" signal and clears the field.
    final photo = f['profileImagePath'];
    if (photo is String) update[kProfilePhotoField] = photo;

    return update;
  }

  /// Same rules as the web app, in the same order, so both clients reject the
  /// same input.
  String? validate(Map<String, dynamic> f) {
    if (!civilStatuses.contains(f['civilStatus'])) {
      return 'A valid civil status is required.';
    }
    if (!genders.contains(f['gender'])) return 'A valid gender is required.';
    if (requiredError(f['address'] as String?) != null) {
      return 'Address is required.';
    }

    final contact = phoneError(f['contactNumber'] as String?, 'Contact number');
    if (contact != null) return contact;

    final home = optionalPhoneError(f['homePhone'] as String?, 'Home phone');
    if (home != null) return home;

    final emergencyPhone = optionalPhoneError(
      f['emergencyContactNumber'] as String?,
      'Emergency contact number',
    );
    if (emergencyPhone != null) return emergencyPhone;

    final email = emailError(f['email'] as String?);
    if (email != null) return email;

    for (final key in [
      'emergencyContactName',
      'emergencyContactRelationship',
      'emergencyContactNumber',
    ]) {
      if (requiredError(f[key] as String?) != null) {
        return 'Emergency contact name, relationship, and number are all required.';
      }
    }

    final birthday = f['birthday'] as String?;
    if (birthday == null || birthday.isEmpty) {
      return 'Birthday is required.';
    }
    if (isFutureDate(birthday)) return 'Birthday cannot be in the future.';
    if (isTooOldDate(birthday)) {
      return 'Birthday is too far in the past — please check the year.';
    }

    if (f['civilStatus'] == 'Married') {
      if (requiredError(f['spouseName'] as String?) != null) {
        return 'Spouse name is required when civil status is Married.';
      }
      final spouseBirthday = f['spouseBirthdate'] as String?;
      if (spouseBirthday != null && spouseBirthday.isNotEmpty) {
        if (isFutureDate(spouseBirthday)) {
          return 'Spouse birthdate cannot be in the future.';
        }
        final age = ageFromBirthday(spouseBirthday);
        if (age != null && age < 18) {
          return 'Spouse must be at least 18 years old.';
        }
      }
    }
    return null;
  }
}
