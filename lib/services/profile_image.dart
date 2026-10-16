import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Resident document field holding the photo, shared with the web portal's
/// `uploadProfileImage` so both clients write the same shape.
const kProfilePhotoField = 'ProfileImagePath';

/// The web portal stores the photo as a base64 data URL inside the resident
/// document rather than in Cloud Storage, so the rules below mirror
/// `uploadImage` in `src/api/profileLocal.js`: JPG or PNG, under 3MB.
const kMaxProfilePhotoBytes = 3 * 1024 * 1024;

/// Photos are downscaled by the plugin during decode, so the stored data URL
/// stays small. This matters more than it looks: `ProfileRepository.watch`
/// streams the whole resident document to the dashboard and the profile screen,
/// so an undownscaled 3MB photo would push roughly 4MB of base64 through
/// Firestore on every read.
const _pickMaxDimension = 512.0;
const _pickQuality = 80;

/// Outcome of the gallery picker.
class ProfilePhotoResult {
  const ProfilePhotoResult.cancelled()
    : dataUrl = null,
      error = null,
      cancelled = true;

  const ProfilePhotoResult.success(this.dataUrl)
    : error = null,
      cancelled = false;

  const ProfilePhotoResult.failure(this.error)
    : dataUrl = null,
      cancelled = false;

  final String? dataUrl;
  final String? error;
  final bool cancelled;
}

/// Opens the gallery and returns the chosen photo as a data URL.
///
/// Gallery only, and no Android permission is needed: the plugin uses the
/// Android Photo Picker, which grants access to just the picked image. Returns
/// [ProfilePhotoResult.cancelled] when the user backs out.
Future<ProfilePhotoResult> pickProfilePhoto() async {
  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: _pickMaxDimension,
      maxHeight: _pickMaxDimension,
      imageQuality: _pickQuality,
    );
  } catch (_) {
    return const ProfilePhotoResult.failure(
      "Couldn't open your photos. Check your connection and try again.",
    );
  }

  if (picked == null) return const ProfilePhotoResult.cancelled();

  Uint8List bytes;
  try {
    bytes = await picked.readAsBytes();
  } catch (_) {
    return const ProfilePhotoResult.failure(
      "Couldn't read that image. Please choose another one.",
    );
  }

  final dataUrl = encodeProfilePhoto(bytes);
  if (dataUrl == null) {
    return ProfilePhotoResult.failure(_rejectionMessage(bytes));
  }
  return ProfilePhotoResult.success(dataUrl);
}

/// Encodes image bytes as a base64 data URL, or null when the image is not a
/// supported format or is too large to store.
///
/// The mime type is sniffed from the file signature rather than assumed, so a
/// PNG chosen on a device that keeps the original bytes is labelled correctly.
/// The web portal's `<img src>` renders either form.
String? encodeProfilePhoto(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  if (bytes.length > kMaxProfilePhotoBytes) return null;
  final mime = _sniffMime(bytes);
  if (mime == null) return null;
  return 'data:$mime;base64,${base64.encode(bytes)}';
}

/// Decodes a stored [value] back to bytes for display.
///
/// Returns null for anything unusable so callers can fall back to initials
/// rather than rendering a broken image. Handles a base64 data URL, a bare
/// base64 payload, and an `http(s)` download URL.
Uint8List? decodeProfilePhoto(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  if (isRemoteProfilePhoto(trimmed)) return null;

  final marker = trimmed.indexOf(',');
  final payload = marker == -1 ? trimmed : trimmed.substring(marker + 1);
  if (payload.isEmpty) return null;
  try {
    final bytes = base64.decode(payload);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

/// True when [value] is a download URL rather than inline image data, which
/// lets the UI use `Image.network` for it.
bool isRemoteProfilePhoto(String? value) {
  if (value == null) return false;
  final trimmed = value.trim();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
}

String? _sniffMime(Uint8List bytes) {
  bool has(int index, int a, int b, [int? c, int? d]) {
    if (bytes.length <= index) return false;
    if (bytes[index] != a) return false;
    if (b != 0 && bytes[index + 1] != b) return false;
    if (c != null && bytes[index + 2] != c) return false;
    if (d != null && bytes[index + 3] != d) return false;
    return true;
  }

  // JPEG: FF D8 FF
  if (has(0, 0xFF, 0xD8, 0xFF)) return 'image/jpeg';
  // PNG: 89 50 4E 47
  if (has(0, 0x89, 0x50, 0x4E, 0x47)) return 'image/png';
  return null;
}

String _rejectionMessage(Uint8List bytes) {
  if (bytes.isNotEmpty && _sniffMime(bytes) == null) {
    return 'Only JPG or PNG images are allowed.';
  }
  return 'Image must be under 3MB.';
}
