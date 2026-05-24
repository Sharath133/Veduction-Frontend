import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/models/leaderboard_model.dart';
import 'package:veducation_app/providers/duel_provider.dart';
import 'package:veducation_app/providers/leaderboard_provider.dart';
import 'package:veducation_app/utils/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  DuelProvider? _duelProvider;
  bool _duelListenerAttached = false;
  String? _lastLoadedDuelId;

  static final NumberFormat _secondsFormat = NumberFormat('#,##0.##', 'en_IN');
  static final NumberFormat _marksFormat = NumberFormat('#0.##');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duelProv = context.read<DuelProvider>();
    if (!_duelListenerAttached) {
      _duelListenerAttached = true;
      _duelProvider = duelProv;
      duelProv.addListener(_onDuelProviderChanged);
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _onDuelProviderChanged());
  }

  @override
  void dispose() {
    if (_duelListenerAttached && _duelProvider != null) {
      _duelProvider!.removeListener(_onDuelProviderChanged);
    }
    super.dispose();
  }

  void _onDuelProviderChanged() {
    if (!mounted) return;
    final duelId = context.read<DuelProvider>().todayDuel?.id;
    if (duelId == null || duelId.isEmpty) return;

    final lb = context.read<LeaderboardProvider>();
    if (lb.isLoading) return;
    if (duelId == _lastLoadedDuelId &&
        (lb.leaderboard != null || lb.errorMessage != null)) {
      return;
    }
    _lastLoadedDuelId = duelId;
    lb.loadForDuel(duelId);
  }

  Future<void> _onRefresh() async {
    final duelProvider = context.read<DuelProvider>();
    final leaderboardProvider = context.read<LeaderboardProvider>();
    await duelProvider.loadTodayDuel();
    final duelId = duelProvider.todayDuel?.id;
    if (duelId != null && duelId.isNotEmpty) {
      _lastLoadedDuelId = duelId;
      await leaderboardProvider.refresh(duelId);
    } else {
      _lastLoadedDuelId = null;
    }
  }

  String _formatSecondsFromMicroseconds(int? micros) {
    if (micros == null) return '—';
    final seconds = micros / Duration.microsecondsPerSecond;
    return '${_secondsFormat.format(seconds)} sec';
  }

  String _formatReward(LeaderboardRewardModel r) {
    final buf = StringBuffer();
    if (r.amount != null) {
      buf.write('₹${_marksFormat.format(r.amount)}');
    }
    if (buf.isNotEmpty) buf.write(' · ');
    buf.write(r.status);
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: Consumer2<DuelProvider, LeaderboardProvider>(
        builder: (context, duelProvider, leaderboardProvider, _) {
          if (duelProvider.isLoading && duelProvider.todayDuel == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final duelId = duelProvider.todayDuel?.id;
          if (duelId == null || duelId.isEmpty) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.25,
                  ),
                  Icon(Icons.event_busy, size: 56, color: cs.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No duel available',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'When today’s duel is published, rankings will appear here. Pull down to refresh.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (leaderboardProvider.isLoading &&
              leaderboardProvider.leaderboard == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (leaderboardProvider.errorMessage != null &&
              leaderboardProvider.leaderboard == null) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  Icon(Icons.error_outline, size: 56, color: cs.error),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      leaderboardProvider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => leaderboardProvider.loadForDuel(duelId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ),
                ],
              ),
            );
          }

          final lb = leaderboardProvider.leaderboard;
          if (lb == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final my = leaderboardProvider.myEntry;
          final empty = leaderboardProvider.isEmptyBoard;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (my != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _YourRankCard(
                        entry: my,
                        formatTime: _formatSecondsFromMicroseconds,
                        formatReward: _formatReward,
                        marksFormat: _marksFormat,
                      ),
                    ),
                  ),
                if (my == null && leaderboardProvider.myRankMissing)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        child: ListTile(
                          leading: Icon(Icons.info_outline, color: cs.primary),
                          title: const Text('Your result'),
                          subtitle: const Text(
                            'Submit today’s duel to get a rank and appear on the leaderboard.',
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Today’s duel',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (leaderboardProvider.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
                if (empty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_outlined,
                              size: 56, color: cs.outline),
                          const SizedBox(height: 16),
                          Text(
                            'No entries yet',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to complete the duel and claim the top spot.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth),
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.all(
                                    cs.primary.withOpacity(0.08),
                                  ),
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('Rank')),
                                    DataColumn(label: Text('Marks')),
                                    DataColumn(label: Text('Time (sec)')),
                                    DataColumn(label: Text('Rewards')),
                                  ],
                                  rows: [
                                    for (final e in lb.entries)
                                      DataRow(
                                        color: my != null && e.rank == my.rank
                                            ? MaterialStateProperty.all(
                                                cs.secondaryContainer
                                                    .withOpacity(0.65),
                                              )
                                            : null,
                                        cells: [
                                          DataCell(
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '#${e.rank}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                Text(
                                                  e.displayName,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(
                                              _marksFormat.format(e.marks))),
                                          DataCell(
                                            Text(
                                              _formatSecondsFromMicroseconds(
                                                e.timeMicroseconds,
                                              ),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 140,
                                              child: Text(
                                                _formatReward(e.reward),
                                                softWrap: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (!empty && lb.total > lb.entries.length)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Text(
                        'Showing ${lb.entries.length} of ${lb.total} players',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _YourRankCard extends StatelessWidget {
  const _YourRankCard({
    required this.entry,
    required this.formatTime,
    required this.formatReward,
    required this.marksFormat,
  });

  final LeaderboardEntryModel entry;
  final String Function(int? micros) formatTime;
  final String Function(LeaderboardRewardModel r) formatReward;
  final NumberFormat marksFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 3,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin, color: cs.onPrimaryContainer, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Your position',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '#${entry.rank}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                color: cs.onPrimaryContainer.withOpacity(0.9),
              ),
            ),
            const Divider(height: 28),
            _MetricLine(
              label: 'Marks',
              value: marksFormat.format(entry.marks),
              dense: true,
            ),
            _MetricLine(
              label: 'Time',
              value: formatTime(entry.timeMicroseconds),
              dense: true,
            ),
            _MetricLine(
              label: 'Rewards',
              value: formatReward(entry.reward),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.dense = false,
  });

  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 6 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
