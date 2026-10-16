import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_health_portal/services/profile_image.dart';
import 'package:barangay_health_portal/services/profile_repository.dart';
import 'package:barangay_health_portal/theme.dart';
import 'package:barangay_health_portal/widgets/common.dart';

/// Minimal byte headers, enough for the format sniff the encoder relies on.
final jpegBytes = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  1,
  2,
  3,
]);
final pngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  9,
  9,
]);
final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0]);

Widget _host(Widget child, ThemeMode mode) {
  return MaterialApp(
    theme: AppTheme.build(),
    darkTheme: AppTheme.build(brightness: Brightness.dark),
    themeMode: mode,
    home: Scaffold(body: child),
  );
}

void main() {
  group('profile photo encoding', () {
    test('encodes a JPEG as a jpeg data URL', () {
      final encoded = encodeProfilePhoto(jpegBytes);
      expect(encoded, startsWith('data:image/jpeg;base64,'));
      expect(
        decodeProfilePhoto(encoded),
        equals(jpegBytes),
        reason: 'the web portal reads this value straight back out',
      );
    });

    test('labels the mime type from the bytes, not the file extension', () {
      // A device that keeps the original PNG bytes must still produce something
      // an <img src> can render.
      expect(
        encodeProfilePhoto(pngBytes),
        startsWith('data:image/png;base64,'),
      );
    });

    test('round-trips through base64', () {
      final bytes = Uint8List.fromList([...jpegBytes, ...List.filled(200, 42)]);
      expect(decodeProfilePhoto(encodeProfilePhoto(bytes)), equals(bytes));
    });

    test('rejects an unsupported format', () {
      expect(encodeProfilePhoto(gifBytes), isNull);
    });

    test('rejects an empty file', () {
      expect(encodeProfilePhoto(Uint8List(0)), isNull);
    });

    test('rejects anything over 3MB, matching the web limit', () {
      final tooBig = Uint8List(kMaxProfilePhotoBytes + 1);
      tooBig.setRange(0, 4, jpegBytes);
      expect(encodeProfilePhoto(tooBig), isNull);
    });

    test('accepts a file right at the 3MB limit', () {
      final atLimit = Uint8List(kMaxProfilePhotoBytes);
      atLimit.setRange(0, 4, jpegBytes);
      expect(encodeProfilePhoto(atLimit), isNotNull);
    });
  });

  group('profile photo decoding', () {
    test('returns null for a missing or blank value', () {
      expect(decodeProfilePhoto(null), isNull);
      expect(decodeProfilePhoto(''), isNull);
      expect(decodeProfilePhoto('   '), isNull);
    });

    test('returns null for undecodable data instead of throwing', () {
      // A corrupt value must degrade to initials, not crash the profile screen.
      expect(
        decodeProfilePhoto('data:image/jpeg;base64,!!!not-base64!!!'),
        isNull,
      );
      expect(decodeProfilePhoto('data:image/jpeg;base64,'), isNull);
      expect(decodeProfilePhoto('data:text/html,<script>'), isNull);
    });

    test('accepts a bare base64 payload with no data URL prefix', () {
      final payload = base64.encode(jpegBytes);
      expect(decodeProfilePhoto(payload), equals(jpegBytes));
    });

    test('routes remote URLs away from the decoder', () {
      expect(isRemoteProfilePhoto('https://example.com/a.jpg'), isTrue);
      expect(isRemoteProfilePhoto('http://example.com/a.jpg'), isTrue);
      expect(isRemoteProfilePhoto('data:image/jpeg;base64,AA'), isFalse);
      expect(isRemoteProfilePhoto(null), isFalse);
      expect(
        decodeProfilePhoto('https://example.com/a.jpg'),
        isNull,
        reason: 'a URL is rendered with Image.network, not decoded',
      );
    });
  });

  group('profile update merge list', () {
    Map<String, dynamic> baseFields() => {
      'middleName': '',
      'civilStatus': 'Single',
      'gender': 'Male',
      'birthday': '2001-10-15',
      'address': '789 Mabini Street',
      'contactNumber': '09175550123',
      'emergencyContactName': 'Ana Santos',
      'emergencyContactRelationship': 'Mother',
      'emergencyContactNumber': '09175550124',
    };

    test('writes the photo when one is supplied', () {
      final dataUrl = encodeProfilePhoto(jpegBytes);
      final update = ProfileRepository.buildUpdate({
        ...baseFields(),
        'profileImagePath': dataUrl,
      });
      expect(update[kProfilePhotoField], dataUrl);
    });

    test('omits the photo entirely when the field was not touched', () {
      // The edit form submits every field on every save. Writing '' here would
      // silently erase the photo whenever an unrelated field changed.
      final update = ProfileRepository.buildUpdate(baseFields());
      expect(update.containsKey(kProfilePhotoField), isFalse);
    });

    test('omits the photo when it is explicitly null', () {
      final update = ProfileRepository.buildUpdate({
        ...baseFields(),
        'profileImagePath': null,
      });
      expect(update.containsKey(kProfilePhotoField), isFalse);
    });

    test('clears the photo when an empty string is sent', () {
      final update = ProfileRepository.buildUpdate({
        ...baseFields(),
        'profileImagePath': '',
      });
      expect(update[kProfilePhotoField], '');
    });

    test('can never rewrite the fields staff own', () {
      final update = ProfileRepository.buildUpdate({
        ...baseFields(),
        'password': 'hacked',
        'status': 'Active',
        'residentNumber': 'RES-9999',
        'firstName': 'Hacked',
        'lastName': 'Name',
        'profileImagePath': encodeProfilePhoto(pngBytes),
      });
      for (final locked in [
        'Password',
        'Status',
        'ResidentNumber',
        'FirstName',
        'LastName',
        'RegisteredAt',
        'IsArchived',
      ]) {
        expect(
          update.containsKey(locked),
          isFalse,
          reason: 'a profile edit must not be able to write $locked',
        );
      }
    });

    test('drops the spouse block when civil status is not Married', () {
      final update = ProfileRepository.buildUpdate(baseFields());
      expect(update['Spouse'], isNull);
    });
  });

  for (final mode in ThemeMode.values) {
    group('avatar in ${mode.name} mode', () {
      testWidgets('falls back to initials with no photo', (tester) async {
        await tester.pumpWidget(
          _host(const ResidentAvatar(initials: 'MS', photo: null), mode),
        );
        await tester.pumpAndSettle();

        expect(find.text('MS'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('renders a stored photo', (tester) async {
        await tester.pumpWidget(
          _host(
            ResidentAvatar(initials: 'MS', photo: encodeProfilePhoto(pngBytes)),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(ClipOval), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('falls back to initials for a corrupt photo', (tester) async {
        await tester.pumpWidget(
          _host(
            const ResidentAvatar(
              initials: 'MS',
              photo: 'data:image/jpeg;base64,%%%broken%%%',
            ),
            mode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('MS'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows the add and remove actions appropriately', (
        tester,
      ) async {
        var picks = 0;
        var removes = 0;

        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) {
                final photo = _pickerPhoto;
                return ProfilePhotoField(
                  initials: 'MS',
                  photo: photo,
                  onPick: () => setState(() {
                    picks++;
                    _pickerPhoto = encodeProfilePhoto(pngBytes);
                  }),
                  onRemove: () => setState(() {
                    removes++;
                    _pickerPhoto = null;
                  }),
                );
              },
            ),
            mode,
          ),
        );

        expect(find.text('Add photo'), findsOneWidget);
        expect(find.text('Remove photo'), findsNothing);

        await tester.tap(find.text('Add photo'));
        await tester.pumpAndSettle();

        expect(picks, 1);
        expect(find.text('Change photo'), findsOneWidget);
        expect(find.text('Remove photo'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        await tester.tap(find.text('Remove photo'));
        await tester.pumpAndSettle();

        expect(removes, 1);
        expect(find.text('Add photo'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      });

      testWidgets('accepts an https photo for a future storage migration', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const ResidentAvatar(
              initials: 'MS',
              photo: 'https://example.com/photo.jpg',
            ),
            mode,
          ),
        );
        // A network image never resolves in a test; the point is that it is
        // routed to Image.network rather than the base64 decoder.
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}

/// Mutable state for the StatefulBuilder test above.
String? _pickerPhoto;
