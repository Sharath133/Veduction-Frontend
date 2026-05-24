import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:veducation_app/services/api_service.dart';

class AdminPYQsScreen extends StatefulWidget {
  const AdminPYQsScreen({super.key});

  @override
  State<AdminPYQsScreen> createState() => _AdminPYQsScreenState();
}

class _AdminPYQsScreenState extends State<AdminPYQsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _sectionCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sectionsRes = await _api.adminListPYQSections();
      if (sectionsRes.statusCode == 200) {
        setState(() {
          _sectionCategories =
              (sectionsRes.data['categories'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      _showError(e);
    }
  }

  Future<void> _createSection() async {
    if (_sectionCategories.isEmpty) return;

    final title = TextEditingController();
    final order = TextEditingController(text: '0');
    String categoryId = _sectionCategories.first['id'].toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New PYQ section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _sectionCategories
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['title'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => categoryId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Section name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: order,
                  decoration: const InputDecoration(labelText: 'Display order'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      if (title.text.trim().isEmpty) {
        throw Exception('Section name is required');
      }
      await _api.adminCreatePYQSection({
        'category_id': categoryId,
        'title': title.text.trim(),
        'display_order': int.tryParse(order.text.trim()) ?? 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section created')),
      );
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _editSection(Map<String, dynamic> section) async {
    final title = TextEditingController(text: section['title']?.toString());
    final order = TextEditingController(
      text: '${section['display_order'] ?? 0}',
    );
    bool active = section['is_active'] != false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit section'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Section name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: order,
                  decoration: const InputDecoration(labelText: 'Display order'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  value: active,
                  title: const Text('Visible to students'),
                  onChanged: (value) => setDialogState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _api.adminUpdatePYQSection(section['id'].toString(), {
        'title': title.text.trim(),
        'display_order': int.tryParse(order.text.trim()) ?? 0,
        'is_active': active,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section updated')),
      );
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _uploadSectionPdf(String sectionId) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (pick == null) return;

    try {
      final pickedFile = pick.files.single;
      final title = pickedFile.name.replaceFirst(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final fd = FormData.fromMap({
        'title': title,
        'file': await _multipartFileFromPick(pickedFile),
      });
      final res = await _api.adminUploadPYQSectionPdf(sectionId, fd);
      if (mounted && res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF uploaded')),
        );
        _load();
      }
    } catch (e) {
      _showError(e);
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

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiService.errorMessage(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PYQs'),
        actions: [
          IconButton(
            tooltip: 'Create section',
            icon: const Icon(Icons.create_new_folder),
            onPressed: _createSection,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Student PYQ sections',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _createSection,
                          icon: const Icon(Icons.add),
                          label: const Text('Section'),
                        ),
                      ],
                    ),
                  ),
                  if (_sectionCategories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No student sections available'),
                        ),
                      ),
                    )
                  else
                    ..._sectionCategories.map(_buildCategoryCard),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final sections = (category['sections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(category['title'].toString()),
        subtitle: Text('${sections.length} section(s)'),
        children: [
          if (sections.isEmpty)
            const ListTile(title: Text('No sections yet'))
          else
            ...sections.map((section) {
              final pdfs = (section['pdfs'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();
              return ListTile(
                leading: Icon(
                  section['is_active'] == false
                      ? Icons.visibility_off
                      : Icons.folder,
                ),
                title: Text(section['title'].toString()),
                subtitle: Text('${pdfs.length} PDF(s)'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editSection(section);
                    if (value == 'pdf') {
                      _uploadSectionPdf(section['id'].toString());
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit section')),
                    PopupMenuItem(value: 'pdf', child: Text('Add PDF')),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
