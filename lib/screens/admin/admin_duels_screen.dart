import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:veducation_app/services/api_service.dart';

class AdminDuelsScreen extends StatefulWidget {
  const AdminDuelsScreen({super.key});

  @override
  State<AdminDuelsScreen> createState() => _AdminDuelsScreenState();
}

class _AdminDuelsScreenState extends State<AdminDuelsScreen> {
  final _api = ApiService();
  List<dynamic> _duels = [];
  bool _loading = true;

  String _dateToIso(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get _todayIso => _dateToIso(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.adminListDuels();
      if (res.statusCode == 200) {
        setState(() {
          _duels = res.data['duels'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiService.errorMessage(e))));
      }
    }
  }

  Future<void> _openDuelForm({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final dateCtrl =
        TextEditingController(text: existing?['duel_date'] ?? _todayIso);
    final tqCtrl =
        TextEditingController(text: '${existing?['total_questions'] ?? 15}');
    final tlCtrl =
        TextEditingController(text: '${existing?['time_limit_minutes'] ?? 15}');
    final feeCtrl =
        TextEditingController(text: '${existing?['registration_fee'] ?? ''}');
    final poolCtrl =
        TextEditingController(text: '${existing?['prize_pool'] ?? 0}');
    final statusCtrl =
        TextEditingController(text: existing?['status'] ?? 'upcoming');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit duel' : 'Create duel'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duel date (YYYY-MM-DD)',
                    hintText: 'Today',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: isEdit
                      ? null
                      : () async {
                          final initialDate =
                              DateTime.tryParse(dateCtrl.text) ??
                                  DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: initialDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                          );
                          if (picked != null) {
                            dateCtrl.text = _dateToIso(picked);
                          }
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tqCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Total questions'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tlCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Time limit (minutes)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Registration fee (₹)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: poolCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Prize pool (₹)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                if (isEdit) const SizedBox(height: 16),
                if (isEdit)
                  TextField(
                    controller: statusCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      hintText: 'upcoming | active | completed | settled',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final tq = int.tryParse(tqCtrl.text.trim());
      final tl = int.tryParse(tlCtrl.text.trim());
      if (tq == null || tl == null) {
        throw Exception('Questions and time limit must be integers');
      }
      if (isEdit) {
        final id = existing['id'] as String;
        final body = <String, dynamic>{
          'total_questions': tq,
          'time_limit_minutes': tl,
          'registration_fee': num.tryParse(feeCtrl.text.trim()),
          'prize_pool': num.tryParse(poolCtrl.text.trim()),
          'status':
              statusCtrl.text.trim().isEmpty ? null : statusCtrl.text.trim(),
        }..removeWhere((k, v) => v == null);
        final res = await _api.adminUpdateDuel(id, body);
        if (!mounted) return;
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Duel updated')));
          _load();
        }
      } else {
        final duelDate = dateCtrl.text.trim();
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(duelDate)) {
          throw Exception('Duel date must be in YYYY-MM-DD format');
        }
        final res = await _api.adminCreateDuel({
          'duel_date': duelDate,
          'total_questions': tq,
          'time_limit_minutes': tl,
          'registration_fee': num.tryParse(feeCtrl.text.trim()) ?? 0,
          'prize_pool': num.tryParse(poolCtrl.text.trim()) ?? 0,
        });
        if (!mounted) return;
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Duel created')));
          _load();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiService.errorMessage(e))));
      }
    }
  }

  Future<void> _uploadCsv(String duelId) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (pick == null) return;
    try {
      final fd = FormData.fromMap({
        'file': await _multipartFileFromPick(pick.files.single),
      });
      final res = await _api.adminUploadDuelCsv(duelId, fd);
      if (res.statusCode == 200 && mounted) {
        final err = res.data['errors'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  err != null ? 'Imported with errors: $err' : 'CSV imported')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiService.errorMessage(e))));
      }
    }
  }

  Future<MultipartFile> _multipartFileFromPick(PlatformFile file) async {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Selected file could not be read. Please try again.');
      }
      return MultipartFile.fromBytes(bytes, filename: file.name);
    }

    final path = file.path;
    if (path != null) {
      return MultipartFile.fromFile(path, filename: file.name);
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Selected file could not be read. Please try again.');
    }
    return MultipartFile.fromBytes(bytes, filename: file.name);
  }

  Future<void> _deleteDuel(String duelId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete duel?'),
        content: const Text('Only allowed if there are no registrations.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.adminDeleteDuel(duelId);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Deleted')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ApiService.errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Duels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openDuelForm(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _duels.isEmpty
                  ? const Center(child: Text('No duels'))
                  : ListView.builder(
                      itemCount: _duels.length,
                      itemBuilder: (context, i) {
                        final d = _duels[i] as Map<String, dynamic>;
                        final id = d['id'] as String;
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text('${d['duel_date']}'),
                            subtitle: Text(
                              'Status: ${d['status']} · Q: ${d['total_questions']} · '
                              '${d['time_limit_minutes']} min · Fee ₹${d['registration_fee']}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _openDuelForm(existing: d);
                                if (v == 'csv') _uploadCsv(id);
                                if (v == 'del') _deleteDuel(id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'csv', child: Text('Upload CSV')),
                                PopupMenuItem(
                                    value: 'del', child: Text('Delete')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
