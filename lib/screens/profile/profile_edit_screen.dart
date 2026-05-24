import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/providers/auth_provider.dart';

/// Indian 10-digit mobile (same rule as backend `validate_mobile_number`).
final RegExp _kIndianMobile = RegExp(r'^[6-9]\d{9}$');

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _mobileController = TextEditingController(text: user?.mobileNumber ?? '');
    _mobileController.addListener(_onMobileEdited);
  }

  void _onMobileEdited() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final trimmed = _mobileController.text.trim();
    if (trimmed == user.mobileNumber && _otpSent) {
      setState(() {
        _otpSent = false;
        _otpController.clear();
      });
    }
  }

  @override
  void dispose() {
    _mobileController.removeListener(_onMobileEdited);
    _nameController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final mobileChanged = mobile != user.mobileNumber;
    final nameChanged = name != (user.name ?? '');

    if (!mobileChanged && !nameChanged) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    if (mobileChanged) {
      if (!_kIndianMobile.hasMatch(mobile)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid 10-digit Indian mobile number'),
          ),
        );
        return;
      }
      if (!_otpSent) {
        final err = await auth.sendMobileChangeOtp(mobile);
        if (!mounted) return;
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          return;
        }
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to the new number. Enter it below.')),
        );
        return;
      }
      final otp = _otpController.text.trim();
      if (otp.length != 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the 6-digit OTP')),
        );
        return;
      }
      final err = await auth.confirmMobileChange(mobile, otp);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      setState(() {
        _otpSent = false;
        _otpController.clear();
      });
    }

    final latest = auth.user;
    if (latest != null && name != (latest.name ?? '')) {
      final err = await auth.updateUserProfile(name: name);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final busy = auth.isLoading;
          return AbsorbPointer(
            absorbing: busy,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        border: OutlineInputBorder(),
                        helperText:
                            'Changing mobile sends an OTP to the new number.',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Mobile is required';
                        }
                        if (!_kIndianMobile.hasMatch(v.trim())) {
                          return 'Enter a valid 10-digit Indian mobile';
                        }
                        return null;
                      },
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otpController,
                        decoration: const InputDecoration(
                          labelText: 'OTP',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _save,
                      child: busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_otpSent ? 'Verify OTP & save' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
