import 'package:flutter/material.dart';

import '../services/auth_repository.dart';
import '../services/profile_image.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

/// Self-registration. Submits a `Pending` resident for staff review.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _birthday = TextEditingController();
  final _email = TextEditingController();
  final _contactNumber = TextEditingController();
  final _address = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyRelationship = TextEditingController();
  final _emergencyNumber = TextEditingController();

  String _gender = 'Male';
  String _civilStatus = 'Single';
  DateTime? _pickedBirthday;

  /// Optional. Held as a data URL so it rides along in the same `set` that
  /// creates the resident document, which is the only way to attach it before
  /// the applicant has a document id.
  String? _photo;
  bool _pickingPhoto = false;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _middleName,
      _lastName,
      _birthday,
      _email,
      _contactNumber,
      _address,
      _emergencyName,
      _emergencyRelationship,
      _emergencyNumber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _pickedBirthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    setState(() {
      _pickedBirthday = picked;
      _birthday.text = formatDate(picked);
    });
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

  String _initials() {
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    return '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
        .toUpperCase();
  }

  /// The web app stores dates as `YYYY-MM-DD` strings, so the picker output is
  /// formatted to match instead of relying on the device locale.
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await AuthRepository().register(
      fields: {
        'FirstName': _firstName.text.trim(),
        'MiddleName': _middleName.text.trim(),
        'LastName': _lastName.text.trim(),
        'Birthday': formatDate(_pickedBirthday!),
        'Gender': _gender,
        'CivilStatus': _civilStatus,
        'Email': _email.text.trim().toLowerCase(),
        'ContactNumber': _contactNumber.text.trim(),
        'Address': _address.text.trim(),
        'EmergencyContactName': _emergencyName.text.trim(),
        'EmergencyContactRelationship': _emergencyRelationship.text.trim(),
        'EmergencyContactNumber': _emergencyNumber.text.trim(),
        if (_photo != null) kProfilePhotoField: _photo,
      },
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as a resident')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.successBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.successBorder),
                  ),
                  child: Text(
                    'Your Resident Number is assigned automatically when you submit. '
                    'The Barangay Health Center must approve your registration before you can sign in.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.successFg,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colors.errorBorder),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.errorFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const SectionHeader('Photo'),
                ProfilePhotoField(
                  initials: _initials(),
                  photo: _photo,
                  busy: _pickingPhoto,
                  onPick: _choosePhoto,
                  onRemove: () => setState(() => _photo = null),
                ),

                const SizedBox(height: 28),

                const SectionHeader('Personal details'),
                const FieldLabel('First name'),
                TextFormField(
                  key: const Key('reg_firstName'),
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  validator: requiredError,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Middle name', optional: true),
                TextFormField(
                  key: const Key('reg_middleName'),
                  controller: _middleName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Last name'),
                TextFormField(
                  key: const Key('reg_lastName'),
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  validator: requiredError,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Date of birth'),
                TextFormField(
                  key: const Key('reg_birthday'),
                  controller: _birthday,
                  readOnly: true,
                  onTap: _pickBirthday,
                  validator: requiredError,
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: context.colors.textSecondary,
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
                    for (final c in civilStatuses)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) =>
                      setState(() => _civilStatus = v ?? _civilStatus),
                ),

                const SizedBox(height: 28),
                const SectionHeader('Contact details'),
                const FieldLabel('Email'),
                TextFormField(
                  key: const Key('reg_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                  ),
                  validator: emailError,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Contact number'),
                TextFormField(
                  key: const Key('reg_contactNumber'),
                  controller: _contactNumber,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    hintText: '09XXXXXXXXX',
                    counterText: '',
                  ),
                  validator: (v) => phoneError(v, 'Contact number'),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Address'),
                TextFormField(
                  key: const Key('reg_address'),
                  controller: _address,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                  validator: requiredError,
                ),

                const SizedBox(height: 28),
                const SectionHeader('Emergency contact'),
                const FieldLabel('Name'),
                TextFormField(
                  key: const Key('reg_emergencyName'),
                  controller: _emergencyName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: requiredError,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Relationship'),
                TextFormField(
                  key: const Key('reg_emergencyRelationship'),
                  controller: _emergencyRelationship,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: requiredError,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Contact number'),
                TextFormField(
                  key: const Key('reg_emergencyNumber'),
                  controller: _emergencyNumber,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    hintText: '09XXXXXXXXX',
                    counterText: '',
                  ),
                  validator: (v) => phoneError(v, 'Emergency contact number'),
                ),

                const SizedBox(height: 32),
                FilledButton(
                  key: const Key('reg_submit'),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit registration'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
