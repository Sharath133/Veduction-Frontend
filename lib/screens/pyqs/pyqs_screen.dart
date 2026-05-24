import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veducation_app/services/api_service.dart';

class PYQsScreen extends StatefulWidget {
  const PYQsScreen({super.key});

  @override
  State<PYQsScreen> createState() => _PYQsScreenState();
}

class _PYQsScreenState extends State<PYQsScreen> {
  final _api = ApiService();
  List<_PYQCategory> _categories = [];
  int _selectedCategoryIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getPYQSections();
      final raw = (res.data['categories'] as List<dynamic>? ?? []);
      if (!mounted) return;
      setState(() {
        _categories = raw
            .map((item) => _PYQCategory.fromJson(item as Map<String, dynamic>))
            .toList();
        _selectedCategoryIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.errorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(child: Text('No PYQ sections available'));
    }

    final selectedCategory = _categories[_selectedCategoryIndex];

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'PYQs Section',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: const Color(0xFF0F766E),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) {
                final useGrid = constraints.maxWidth >= 720;

                if (useGrid) {
                  return Row(
                    children: List.generate(_categories.length, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == _categories.length - 1 ? 0 : 16,
                          ),
                          child: _CategoryButton(
                            category: _categories[index],
                            isSelected: index == _selectedCategoryIndex,
                            onTap: () => _selectCategory(index),
                          ),
                        ),
                      );
                    }),
                  );
                }

                return Column(
                  children: List.generate(_categories.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _categories.length - 1 ? 0 : 12,
                      ),
                      child: _CategoryButton(
                        category: _categories[index],
                        isSelected: index == _selectedCategoryIndex,
                        onTap: () => _selectCategory(index),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              selectedCategory.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (selectedCategory.sections.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sections available'),
                ),
              )
            else
              ...selectedCategory.sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SectionTile(
                    section: section,
                    onPdfTap: _openPdf,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  Future<void> _openPdf(_PYQPdf pdf) async {
    final uri = Uri.parse(_absoluteUploadUrl(pdf.url));
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF')),
      );
    }
  }

  String _absoluteUploadUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    final base = Uri.parse(ApiService.baseUrl);
    return '${base.origin}$pathOrUrl';
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _PYQCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected ? colorScheme.primary : colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.primary, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                category.iconData,
                color: isSelected ? Colors.white : colorScheme.primary,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                category.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isSelected ? Colors.white : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.onPdfTap,
  });

  final _PYQSection section;
  final ValueChanged<_PYQPdf> onPdfTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.description),
        title: Text(section.title),
        subtitle: Text('${section.pdfs.length} PDF(s)'),
        children: section.pdfs.isEmpty
            ? const [
                ListTile(
                  title: Text('No PDFs added yet'),
                ),
              ]
            : section.pdfs
                .map(
                  (pdf) => ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text(pdf.title),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => onPdfTap(pdf),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _PYQCategory {
  const _PYQCategory({
    required this.id,
    required this.code,
    required this.title,
    required this.icon,
    required this.sections,
  });

  factory _PYQCategory.fromJson(Map<String, dynamic> json) {
    return _PYQCategory(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString(),
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((item) => _PYQSection.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String code;
  final String title;
  final String? icon;
  final List<_PYQSection> sections;

  IconData get iconData {
    switch (icon) {
      case 'account_balance':
        return Icons.account_balance;
      case 'location_city':
        return Icons.location_city;
      case 'public':
        return Icons.public;
      default:
        return Icons.folder;
    }
  }
}

class _PYQSection {
  const _PYQSection({
    required this.id,
    required this.title,
    required this.pdfs,
  });

  factory _PYQSection.fromJson(Map<String, dynamic> json) {
    return _PYQSection(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      pdfs: (json['pdfs'] as List<dynamic>? ?? [])
          .map((item) => _PYQPdf.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String title;
  final List<_PYQPdf> pdfs;
}

class _PYQPdf {
  const _PYQPdf({
    required this.id,
    required this.title,
    required this.url,
  });

  factory _PYQPdf.fromJson(Map<String, dynamic> json) {
    return _PYQPdf(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final String url;
}
