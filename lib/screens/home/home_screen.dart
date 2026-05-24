import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:veducation_app/config/app_flags.dart';
import 'package:veducation_app/providers/auth_provider.dart';
import 'package:veducation_app/providers/duel_provider.dart';
import 'package:veducation_app/screens/auth/login_screen.dart';
import 'package:veducation_app/screens/duel/duel_registration_screen.dart';
import 'package:veducation_app/screens/duel/instructions_screen.dart';
import 'package:veducation_app/screens/duel/test_result_screen.dart';
import 'package:veducation_app/screens/pyqs/pyqs_screen.dart';
import 'package:veducation_app/screens/leaderboard/leaderboard_screen.dart';
import 'package:veducation_app/screens/rewards/rewards_screen.dart';
import 'package:veducation_app/screens/referral/referral_screen.dart';
import 'package:veducation_app/screens/contact/contact_screen.dart';
import 'package:veducation_app/screens/profile/profile_details_screen.dart';
import 'package:veducation_app/screens/admin/admin_login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Widget? initialScreen;

  const HomeScreen({super.key, this.initialScreen});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Widget _currentScreen;

  @override
  void initState() {
    super.initState();
    _currentScreen = widget.initialScreen ?? const DashboardTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DuelProvider>(context, listen: false).loadTodayDuel();
    });
  }

  void _navigateToScreen(Widget screen) {
    setState(() {
      _currentScreen = screen;
    });
    Navigator.of(context).pop(); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V Education'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'V Education',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Quiz & Duel Platform',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.home,
              title: 'Home',
              onTap: () => _navigateToScreen(const DashboardTab()),
            ),
            _buildDrawerItem(
              icon: Icons.book,
              title: 'PYQs',
              onTap: () => _navigateToScreen(const PYQsScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.leaderboard,
              title: 'Leaderboard',
              onTap: () => _navigateToScreen(const LeaderboardScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.card_giftcard,
              title: 'Your Efforts & Rewards',
              onTap: () => _navigateToScreen(const RewardsScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.share,
              title: 'Refer and Earn',
              onTap: () => _navigateToScreen(const ReferralScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.contact_support,
              title: 'Connect with Us',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ContactScreen()),
                );
              },
            ),
            const Divider(),
            if (kShowStudentAdminPortal) ...[
              _buildDrawerItem(
                icon: Icons.admin_panel_settings,
                title: 'Admin Portal',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminLoginScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
            ],
            _buildDrawerItem(
              icon: Icons.person,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileDetailsScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
      body: _currentScreen,
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _handleLogout() async {
    final navigator = Navigator.of(context);
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  TestResultScreen? _buildResultScreen(
    String duelId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final tm = data['total_marks'];
    if (tm is! num) return null;

    final rawTime = data['time_taken_seconds'];
    final c = data['correct_answers'];
    final w = data['wrong_answers'];
    final u = data['unanswered'];

    return TestResultScreen(
      duelId: duelId,
      totalMarks: tm.toDouble(),
      timeTakenSeconds: rawTime is num ? rawTime.toDouble() : null,
      correctAnswers: c is num ? c.toInt() : null,
      wrongAnswers: w is num ? w.toInt() : null,
      unanswered: u is num ? u.toInt() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DuelProvider>(
      builder: (context, duelProvider, child) {
        if (duelProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final duel = duelProvider.todayDuel;
        final isRegistered = duelProvider.isRegisteredForToday;
        final isSubmitted = duelProvider.hasSubmittedToday;
        final registrationId = duelProvider.todayRegistrationId;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (duel != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSubmitted
                              ? "Today's duel submitted"
                              : isRegistered
                                  ? "You're registered for today's duel"
                                  : "Register here for today's duel",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Date: ${duel.duelDate}'),
                        Text('Questions: ${duel.totalQuestions}'),
                        Text('Time: ${duel.timeLimitMinutes} minutes'),
                        Text('Fee: ₹${duel.registrationFee}'),
                        Text('Prize Pool: ₹${duel.prizePool}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (isSubmitted) {
                              final result = _buildResultScreen(
                                duel.id,
                                duelProvider.todayResult,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      result ??
                                      TestResultScreen(
                                        duelId: duel.id,
                                        totalMarks: 0,
                                      ),
                                ),
                              );
                              return;
                            }

                            if (isRegistered && registrationId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InstructionsScreen(
                                    duelId: duel.id,
                                    registrationId: registrationId,
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DuelRegistrationScreen(
                                  duelId: duel.id,
                                  registrationFee: duel.registrationFee,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            isSubmitted
                                ? 'View Score'
                                : isRegistered
                                    ? 'Continue'
                                    : 'Register Now',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No duel available for today'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}


