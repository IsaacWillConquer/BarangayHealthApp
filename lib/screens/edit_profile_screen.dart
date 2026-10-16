import 'package:flutter/material.dart';

import '../services/profile_image.dart';
import '../services/profile_repository.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

/// Editable profile form.
///
/// Only the fields in [ProfileRepository.update] are sent, so a save cannot
/// rewrite `FirstName`, `LastName`, `Password`, `Status`, or `ResidentNumber`.
/// Name fields are displayed read-only here because staff own identity changes.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.current,
  });

  final ProfileRepository profile;
  final Map<String, dynamic> current;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final Map<String, TextEditingController> _c = {
    'middleName': TextEditingController(text: _str('MiddleName')),
    'extensionName': TextEditingController(text: _str('ExtensionName')),
    'birthday': TextEditingController(text: _str('Birthday')),
    'email': TextEditingController(text: _str('Email')),
    'contactNumber': TextEditingController(text: _str('ContactNumber')),
    'homePhone': TextEditingController(text: _str('HomePhone')),
    'address': TextEditingController(text: _str('Address')),
    'address2': TextEditingController(text: _str('Address2')),
    'emergencyContactName': TextEditingController(
      text: _str('EmergencyContactName'),
    ),
    'emergencyContactRelationship': TextEditingController(
      text: _str('EmergencyContactRelationship'),
    ),
    'emergencyContactNumber': TextEditingController(
      text: _str('EmergencyContactNumber'),
    ),
    'occupation': TextEditingController(text: _str('Occupation')),
    'occupationLocation': TextEditingController(
      text: _str('OccupationLocation'),
    ),
    'fatherName': TextEditingController(text: _str('FatherName')),
    'motherName': TextEditingController(text: _str('MotherName')),
    'reference1Name': TextEditingController(text: _str('Reference1Name')),
    'reference1Contact': TextEditingController(text: _str('Reference1Contact')),
    'reference2Name': TextEditingController(text: _str('Reference2Name')),
    'reference2Contact': TextEditingController(text: _str('Reference2Contact')),
    'bio': TextEditingController(text: _str('Bio')),
    'spouseName': TextEditingController(),
    'spouseBirthdate': TextEditingController(),
    'spouseCivilStatus': TextEditingController(),
    'spouseStatus': TextEditingController(),
  };

  late String _gender = _str('Gender').isEmpty ? 'Male' : _str('Gender');
  late String _civilStatus = civilStatuses.contains(_str('CivilStatus'))
      ? _str('CivilStatus')
      : 'Single';

  bool _busy = false;
  bool _pickingPhoto = false;
  String? _error;

  /// `null` means the photo was not touched, so the field is left out of the
  /// update entirely. An empty string is the explicit "remove" signal.
  String? _photo;

  /// What the avatar should show right now: the pending choice if there is
  /// one, otherwise the stored value.
  String? get _displayPhoto {
    if (_photo != null) return _photo!.isEmpty ? null : _photo;
    final stored = _str(kProfilePhotoField);
    return stored.isEmpty ? null : stored;
  }

  String get _initials {
    final first = _str('FirstName');
    final last = _str('LastName');
    return '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
        .toUpperCase();
  }

  String _str(String key) => (widget.current[key] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    final spouse = widget.current['Spouse'];
    if (spouse is Map) {
      _c['spouseName']!.text = (spouse['Name'] as String?) ?? '';
      _c['spouseBirthdate']!.text = (spouse['Birthdate'] as String?) ?? '';
      _c['spouseCivilStatus']!.text = (spouse['CivilStatus'] as String?) ?? '';
      _c['spouseStatus']!.text = (spouse['Status'] as String?) ?? 'Alive';
    }
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String key, {int maxYearsBack = 120}) async {
    final current = DateTime.tryParse(_c[key]!.text);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - maxYearsBack),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _c[key]!.text = formatDate(picked));
  }

  Future<void> _choosePhoto() async {
    setState(() => _pickingPhoto = true);
    final result = await pickProfilePhoto();
    if (!mounted) return;
    setState(() => _pickingPhoto = false);
    if (result.cancelled) return;
    if (result.dataUrl != null) {
      setState(() {
        _photo = result.dataUrl;
        _error = null;
      });
      return;
    }
    setState(() => _error = result.error);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final fields = <String, dynamic>{
      for (final e in _c.entries) e.key: e.value.text.trim(),
    };
    fields['gender'] = _gender;
    fields['civilStatus'] = _civilStatus;
    if (_photo != null) fields['profileImagePath'] = _photo;

    final validationError = widget.profile.validate(fields);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await widget.profile.update(fields);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final married = _civilStatus == 'Married';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (_error != null) ...[
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.errorBorder),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 13, color: context.colors.errorFg),
                ),
              ),
              const SizedBox(height: 20),
            ],

            const SectionHeader('Photo'),
            ProfilePhotoField(
              initials: _initials,
              photo: _displayPhoto,
              busy: _pickingPhoto,
              onPick: _choosePhoto,
              onRemove: _displayPhoto == null
                  ? null
                  : () => setState(() => _photo = ''),
            ),

            const SizedBox(height: 28),

            const SectionHeader('Name'),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow('First name', _str('FirstName')),
                    InfoRow('Middle name', _c['middleName']!.text),
                    InfoRow('Last name', _str('LastName')),
                    const SizedBox(height: 8),
                    Text(
                      'Ask the Barangay Health Center to change your first or last name.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader('Personal'),
            const FieldLabel('Suffix', optional: true),
            TextField(
              controller: _c['extensionName'],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Jr., III'),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Date of birth'),
            TextField(
              controller: _c['birthday'],
              readOnly: true,
              onTap: () => _pickDate('birthday'),
              decoration: InputDecoration(
                hintText: 'YYYY-MM-DD',
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: context.colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Gender'),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              items: [
                for (final g in genders)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Civil status'),
            DropdownButtonFormField<String>(
              initialValue: _civilStatus,
              items: [
                for (final s in civilStatuses)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) =>
                  setState(() => _civilStatus = v ?? _civilStatus),
            ),

            if (married) ...[
              const SizedBox(height: 20),
              const FieldLabel('Spouse name'),
              TextField(
                controller: _c['spouseName'],
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Spouse birthdate', optional: true),
              TextField(
                controller: _c['spouseBirthdate'],
                readOnly: true,
                onTap: () => _pickDate('spouseBirthdate'),
                decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
              ),
            ],

            const SizedBox(height: 24),
            const SectionHeader('Contact'),
            const FieldLabel('Email'),
            TextField(
              controller: _c['email'],
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Contact number'),
            TextField(
              controller: _c['contactNumber'],
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '09XXXXXXXXX',
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Home phone', optional: true),
            TextField(
              controller: _c['homePhone'],
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '09XXXXXXXXX',
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Address'),
            TextField(controller: _c['address'], maxLines: 2),
            const SizedBox(height: 14),
            const FieldLabel('Address line 2', optional: true),
            TextField(controller: _c['address2']),

            const SizedBox(height: 24),
            const SectionHeader('Emergency contact'),
            const FieldLabel('Name'),
            TextField(
              controller: _c['emergencyContactName'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Relationship'),
            TextField(
              controller: _c['emergencyContactRelationship'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Contact number'),
            TextField(
              controller: _c['emergencyContactNumber'],
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: const InputDecoration(
                counterText: '',
                hintText: '09XXXXXXXXX',
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader('Household'),
            const FieldLabel('Father name', optional: true),
            TextField(
              controller: _c['fatherName'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Mother name', optional: true),
            TextField(
              controller: _c['motherName'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Reference 1', optional: true),
            TextField(
              controller: _c['reference1Name'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Reference 1 contact', optional: true),
            TextField(
              controller: _c['reference1Contact'],
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Reference 2', optional: true),
            TextField(
              controller: _c['reference2Name'],
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Reference 2 contact', optional: true),
            TextField(
              controller: _c['reference2Contact'],
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 24),
            const SectionHeader('Work'),
            const FieldLabel('Occupation', optional: true),
            TextField(controller: _c['occupation']),
            const SizedBox(height: 14),
            const FieldLabel('Employer or school', optional: true),
            TextField(controller: _c['occupationLocation']),
            const SizedBox(height: 14),
            const FieldLabel('About', optional: true),
            TextField(controller: _c['bio'], maxLines: 4),

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save changes'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
