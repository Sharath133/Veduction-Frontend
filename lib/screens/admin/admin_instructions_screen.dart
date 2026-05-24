import 'package:flutter/material.dart';
import 'package:veducation_app/services/api_service.dart';

class AdminInstructionsScreen extends StatefulWidget {
  const AdminInstructionsScreen({super.key});

  @override
  State<AdminInstructionsScreen> createState() =>
      _AdminInstructionsScreenState();
}

class _AdminInstructionsScreenState extends State<AdminInstructionsScreen> {
  final _api = ApiService();
  final _enCtrl = TextEditingController();
  final _teCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _enCtrl.dispose();
    _teCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.adminGetDuelInstructions();
      if (!mounted) return;
      if (res.statusCode == 200) {
        _enCtrl.text = '${res.data['instructions_en'] ?? ''}';
        _teCtrl.text = '${res.data['instructions_te'] ?? ''}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load instructions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final en = _enCtrl.text.trim();
    final te = _teCtrl.text.trim();
    if (en.isEmpty || te.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both languages are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _api.adminUpdateDuelInstructions(en, te);
      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instructions updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save instructions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duel Instructions'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _saving ? null : _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InstructionEditor(
                  title: 'English',
                  controller: _enCtrl,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 16),
                _InstructionEditor(
                  title: 'Telugu',
                  controller: _teCtrl,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save instructions'),
                ),
              ],
            ),
    );
  }
}

class _InstructionEditor extends StatelessWidget {
  const _InstructionEditor({
    required this.title,
    required this.controller,
    required this.textDirection,
  });

  final String title;
  final TextEditingController controller;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textDirection: textDirection,
              minLines: 14,
              maxLines: 24,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
