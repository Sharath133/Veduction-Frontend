import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/providers/leaderboard_provider.dart';

/// Leaderboard for a specific duel (uses GET /leaderboard/{duelId}).
class DuelLeaderboardScreen extends StatefulWidget {
  final String duelId;

  const DuelLeaderboardScreen({super.key, required this.duelId});

  @override
  State<DuelLeaderboardScreen> createState() => _DuelLeaderboardScreenState();
}

class _DuelLeaderboardScreenState extends State<DuelLeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().loadForDuel(widget.duelId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Consumer<LeaderboardProvider>(
        builder: (context, lb, _) {
          if (lb.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (lb.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(lb.errorMessage!, textAlign: TextAlign.center),
              ),
            );
          }
          final board = lb.leaderboard;
          if (board == null || board.entries.isEmpty) {
            return const Center(child: Text('No entries yet for this duel.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: board.entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = board.entries[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${e.rank}')),
                title: Text(e.displayName),
                subtitle: Text('Marks: ${e.marks.toStringAsFixed(2)}'),
              );
            },
          );
        },
      ),
    );
  }
}
