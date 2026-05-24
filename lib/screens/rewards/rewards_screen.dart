import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:veducation_app/services/api_service.dart';

/// Seconds between rotating the two motivational quotes.
const int kRewardsQuoteRotationSeconds = 8;

class _MotivationalQuote {
  const _MotivationalQuote(this.en, this.te);
  final String en;
  final String te;
}

const List<_MotivationalQuote> kRewardsQuotes = [
  _MotivationalQuote(
    'Every duel you finish builds discipline for life\'s bigger tests.',
    'మీరు పూర్తి చేసే ప్రతి పోటీ జీవిత పరీక్షలకు నియమశీలాన్ని నిర్మిస్తుంది.',
  ),
  _MotivationalQuote(
    'Small wins today compound into meaningful progress tomorrow.',
    'ఈ రోజు చిన్న విజయాలు రేపటి అర్థవంతమైన పురోగతిగా మారతాయి.',
  ),
];

class _RewardHistoryRow {
  _RewardHistoryRow({
    required this.duelDate,
    required this.rank,
    required this.amount,
    required this.status,
    required this.recordedAt,
  });

  final String duelDate;
  final int rank;
  final String amount;
  final String status;
  final DateTime recordedAt;

  factory _RewardHistoryRow.fromJson(Map<String, dynamic> json) {
    return _RewardHistoryRow(
      duelDate: json['duel_date'] as String? ?? '',
      rank: json['rank'] as int? ?? 0,
      amount: json['reward_amount'] as String? ?? '0.00',
      status: (json['payment_status'] as String? ?? 'pending').toLowerCase(),
      recordedAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final ApiService _api = ApiService();
  List<_RewardHistoryRow> _rows = [];
  bool _loading = true;
  String? _error;
  bool _unauthorized = false;
  Timer? _quoteTimer;
  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();
    _startQuoteRotation();
    _loadHistory();
  }

  void _startQuoteRotation() {
    _quoteTimer?.cancel();
    _quoteTimer = Timer.periodic(
      const Duration(seconds: kRewardsQuoteRotationSeconds),
      (_) {
        if (!mounted) return;
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % kRewardsQuotes.length;
        });
      },
    );
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
      _unauthorized = false;
    });
    try {
      final response = await _api.getRewardsHistory();
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Unexpected response shape');
      }
      final raw = data['items'];
      if (raw is! List) {
        throw const FormatException('Missing items list');
      }
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(_RewardHistoryRow.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = parsed;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 401) {
        setState(() {
          _rows = [];
          _loading = false;
          _unauthorized = true;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message ?? 'Could not load rewards history';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = kRewardsQuotes[_quoteIndex];
    final dateFmt = DateFormat.yMMMd().add_Hm();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Efforts & Rewards',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'మీ ప్రయత్నాలు & బహుమతులు',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Settlement payouts from daily duels / రోజువారీ పోటీల నుండి చెల్లింపులు',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_unauthorized)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Sign in to view your rewards history.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'మీ బహుమతుల చరిత్ర చూడటానికి సైన్ ఇన్ చేయండి.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadHistory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_rows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No rewards yet',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When you place in the top ranks after settlement, your payouts will appear here.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'సెటిల్మెంట్ తర్వాత అగ్ర ర్యాంకులలో ఉంటే మీ చెల్లింపులు ఇక్కడ కనిపిస్తాయి.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              headingRowHeight: 56,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 64,
                              columnSpacing: 20,
                              columns: [
                                _bilingualColumn('Duel date', 'పోటీ తేదీ'),
                                _bilingualColumn('Rank', 'ర్యాంకు'),
                                _bilingualColumn('Reward (₹)', 'బహుమతి (₹)'),
                                _bilingualColumn('Status', 'స్థితి'),
                                _bilingualColumn('Recorded', 'నమోదు'),
                              ],
                              rows: _rows.map((r) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(r.duelDate)),
                                    DataCell(Text('${r.rank}')),
                                    DataCell(Text(r.amount)),
                                    DataCell(_StatusChip(status: r.status)),
                                    DataCell(Text(dateFmt.format(r.recordedAt.toLocal()))),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_quoteIndex),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.format_quote,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Motivation / ప్రోత్సాహం',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              quote.en,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              quote.te,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _bilingualColumn(String en, String te) {
    return DataColumn(
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(en, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            te,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    switch (status) {
      case 'paid':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'processed':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      default:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
    }
    final label = status.isEmpty ? 'pending' : status;
    return Chip(
      label: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(color: fg, fontSize: 12),
      ),
      backgroundColor: bg,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
