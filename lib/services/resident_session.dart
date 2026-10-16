import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kResidentId = 'resident_id';
const _kRole = 'role';
const _kFirstName = 'first_name';

/// Holds the signed-in resident's Firestore document id.
///
/// Replaces the web app's module-level mutable global in
/// `src/api/currentResident.js`, which falls back to the literal string
/// "resident-1" when nothing is set. Here an unauthenticated app has a null id.
class ResidentSession {
  ResidentSession({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String? _residentId;
  String? _role;
  String? _firstName;

  String? get residentId => _residentId;
  String? get role => _role;
  String? get firstName => _firstName;
  bool get isSignedIn => _residentId != null;

  /// Restores a persisted session. Returns true when one was found.
  Future<bool> restore() async {
    try {
      final id = await _storage.read(key: _kResidentId);
      if (id == null || id.isEmpty) return false;
      _residentId = id;
      _role = await _storage.read(key: _kRole);
      _firstName = await _storage.read(key: _kFirstName);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signIn({
    required String residentId,
    required String role,
    required String firstName,
  }) async {
    _residentId = residentId;
    _role = role;
    _firstName = firstName;
    await _storage.write(key: _kResidentId, value: residentId);
    await _storage.write(key: _kRole, value: role);
    await _storage.write(key: _kFirstName, value: firstName);
  }

  Future<void> signOut() async {
    _residentId = null;
    _role = null;
    _firstName = null;
    await _storage.delete(key: _kResidentId);
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kFirstName);
  }

  /// The signed-in resident's document, or null when signed out.
  Future<DocumentSnapshot<Map<String, dynamic>>?> fetchSelf() async {
    final id = _residentId;
    if (id == null) return null;
    try {
      return await FirebaseFirestore.instance
          .collection('residents')
          .doc(id)
          .get();
    } catch (_) {
      return null;
    }
  }
}
