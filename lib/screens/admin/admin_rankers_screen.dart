import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:veducation_app/services/api_service.dart';

class AdminRankersScreen extends StatefulWidget {
  const AdminRankersScreen({super.key});

  @override
  State<AdminRankersScreen> createState() => _AdminRankersScreenState();
}

class _AdminRankersScreenState extends State<AdminRankersScreen> {
  final _api = ApiService();
  final _dateCtrl = TextEditingController();
  List<dynamic> _entries = [];
  String? _duelMeta;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _entries = [];
      _duelMeta = null;
    });
    try {
      final res = await _api.adminGetTopRankers(_dateCtrl.text.trim(), limit: 10);
      if (res.statusCode == 200) {
        setState(() {
          _entries = res.data['entries'] ?? [];
          _duelMeta =
              'duel_id: ${res.data['duel_id']} · status: ${res.data['duel_status']}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_dateCtrl.text) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top rankers (by duel date)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Duel date',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_today)),
                FilledButton(onPressed: _fetch, child: const Text('Load')),
              ],
            ),
            if (_duelMeta != null) ...[
              const SizedBox(height: 8),
              Text(_duelMeta!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? const Center(child: Text('No data — pick a date with a duel and attempts'))
                      : ListView.separated(
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final e = _entries[i] as Map<String, dynamic>;
                            return ListTile(
                              leading: CircleAvatar(child: Text('${e['rank']}')),
                              title: Text('${e['display_name']}'),
                              subtitle: Text(
                                '${e['mobile_number']}\n'
                                'Marks: ${e['total_marks']} · stored_rank: ${e['attempt_rank_column'] ?? '-'}',
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
