import 'package:flutter/material.dart';
import 'package:veducation_app/services/api_service.dart';
import 'package:veducation_app/screens/duel/test_screen.dart';

class InstructionsScreen extends StatefulWidget {
  final String duelId;
  final String registrationId;

  const InstructionsScreen({
    super.key,
    required this.duelId,
    required this.registrationId,
  });

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  final _apiService = ApiService();
  String? _instructionsEn;
  String? _instructionsTe;
  String _selectedLanguage = 'en';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    try {
      final response = await _apiService.getDuelInstructions();
      if (response.statusCode == 200) {
        setState(() {
          _instructionsEn = response.data['instructions_en'];
          _instructionsTe = response.data['instructions_te'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startTest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TestScreen(
          duelId: widget.duelId,
          registrationId: widget.registrationId,
          language: _selectedLanguage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'Select Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('English'),
                          selected: _selectedLanguage == 'en',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedLanguage = 'en');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('తెలుగు'),
                          selected: _selectedLanguage == 'te',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedLanguage = 'te');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedLanguage == 'en'
                                ? (_instructionsEn ?? 'No instructions available')
                                : (_instructionsTe ?? 'సూచనలు అందుబాటులో లేవు'),
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _startTest,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text(
                      'Start Test',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
