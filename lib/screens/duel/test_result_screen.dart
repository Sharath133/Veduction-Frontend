import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/providers/duel_provider.dart';
import 'package:veducation_app/screens/home/home_screen.dart';
import 'package:veducation_app/screens/leaderboard/leaderboard_screen.dart';

/// Shown after a duel attempt is submitted; data should match POST /duel/submit body.
class TestResultScreen extends StatelessWidget {
  final String duelId;
  final double totalMarks;
  final double? timeTakenSeconds;
  final int? correctAnswers;
  final int? wrongAnswers;
  final int? unanswered;

  const TestResultScreen({
    super.key,
    required this.duelId,
    required this.totalMarks,
    this.timeTakenSeconds,
    this.correctAnswers,
    this.wrongAnswers,
    this.unanswered,
  });

  String _formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '—';
    final s = seconds.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test result'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
              const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Your score',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                totalMarks.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'marks',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              if (correctAnswers != null ||
                  wrongAnswers != null ||
                  unanswered != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _rowStat('Correct', correctAnswers),
                        _rowStat('Wrong', wrongAnswers),
                        _rowStat('Unanswered', unanswered),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Time taken'),
                subtitle: Text(_formatDuration(timeTakenSeconds)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const HomeScreen(
                          initialScreen: LeaderboardScreen(),
                        ),
                      ),
                      (_) => false,
                    );
                  },
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('View leaderboard'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    context.read<DuelProvider>().loadTodayRegistrationStatus();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Back to home'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rowStat(String label, int? value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
