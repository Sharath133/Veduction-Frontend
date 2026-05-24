import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/providers/duel_provider.dart';
import 'package:veducation_app/providers/auth_provider.dart';
import 'package:veducation_app/screens/duel/payment_screen.dart';
import 'package:veducation_app/screens/duel/registration_success_screen.dart';
import 'package:veducation_app/services/api_service.dart';

class DuelRegistrationScreen extends StatefulWidget {
  final String duelId;
  final double registrationFee;

  const DuelRegistrationScreen({
    super.key,
    required this.duelId,
    required this.registrationFee,
  });

  @override
  State<DuelRegistrationScreen> createState() => _DuelRegistrationScreenState();
}

class _DuelRegistrationScreenState extends State<DuelRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _upiMobileController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _upiMobileController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            duelId: widget.duelId,
            registrationFee: widget.registrationFee,
            name: _nameController.text.trim(),
            upiMobile: _upiMobileController.text.trim(),
          ),
        ),
      );
    }
  }

  Future<void> _bypassPaymentForTesting() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final apiService = ApiService();
      final response = await apiService.bypassPaymentForTesting({
        'duel_id': widget.duelId,
        'name': _nameController.text.trim(),
        'upi_mobile': _upiMobileController.text.trim(),
      });

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RegistrationSuccessScreen(
                duelId: widget.duelId,
                registrationId: response.data['registration_id'],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register for Duel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registration Fee',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${widget.registrationFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Less than a single tea ☕',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _upiMobileController,
                decoration: const InputDecoration(
                  labelText: 'UPI Linked Mobile Number',
                  hintText: 'Enter your UPI mobile number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter UPI mobile number';
                  }
                  if (value.trim().length != 10) {
                    return 'Mobile number must be 10 digits';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                    return 'Mobile number must contain only digits';
                  }
                  return null;
                },
                maxLength: 10,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Continue to Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _bypassPaymentForTesting,
                icon: const Icon(Icons.flash_on, color: Colors.orange),
                label: const Text(
                  'Skip Payment (Testing Only)',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⚠️ Testing mode: Skip payment to test test-taking flow',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
