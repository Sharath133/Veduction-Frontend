import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veducation_app/models/user_model.dart';
import 'package:veducation_app/providers/auth_provider.dart';
import 'package:veducation_app/services/api_service.dart';

/// Default loyalty rules (overridden when API returns values).
const int _kDefaultPointsPerReferral = 10;
const int _kDefaultPointsForFreeEntry = 50;

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  int _balancePoints = 0;
  int _pointsPerReferral = _kDefaultPointsPerReferral;
  int _pointsForFreeEntry = _kDefaultPointsForFreeEntry;
  bool _usedProfileFallback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLoyaltyData());
  }

  Future<void> _loadLoyaltyData() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      setState(() {
        _loading = false;
        _balancePoints = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _usedProfileFallback = false;
      _balancePoints = user.loyaltyPoints;
      _pointsPerReferral = _kDefaultPointsPerReferral;
      _pointsForFreeEntry = _kDefaultPointsForFreeEntry;
    });

    Response? referralRes;
    Response? loyaltyRes;
    try {
      referralRes = await _api.getReferralInfo();
    } catch (_) {
      referralRes = null;
    }
    try {
      loyaltyRes = await _api.getLoyaltyPoints();
    } catch (_) {
      loyaltyRes = null;
    }

    var balance = user.loyaltyPoints;
    var perRef = _kDefaultPointsPerReferral;
    var perEntry = _kDefaultPointsForFreeEntry;

    void mergeMap(Map<String, dynamic> m) {
      final p = _firstInt(m, const [
        'loyalty_points',
        'points',
        'balance',
        'total_points',
        'loyalty_points_earned',
      ]);
      if (p != null) balance = p;
      final pr = _firstInt(m, const ['points_per_referral', 'referral_points']);
      if (pr != null) perRef = pr;
      final pe = _firstInt(m, const [
        'points_for_free_entry',
        'free_entry_points',
        'redeem_threshold',
      ]);
      if (pe != null) perEntry = pe;
    }

    final okReferral =
        referralRes != null && referralRes.statusCode == 200 && referralRes.data is Map;
    final okLoyalty =
        loyaltyRes != null && loyaltyRes.statusCode == 200 && loyaltyRes.data is Map;

    if (okReferral) {
      mergeMap(Map<String, dynamic>.from(referralRes!.data as Map));
    }
    if (okLoyalty) {
      mergeMap(Map<String, dynamic>.from(loyaltyRes!.data as Map));
    }

    final usedFallback = !okReferral && !okLoyalty;
    if (usedFallback) {
      balance = user.loyaltyPoints;
      perRef = _kDefaultPointsPerReferral;
      perEntry = _kDefaultPointsForFreeEntry;
    }

    if (!mounted) return;
    setState(() {
      _balancePoints = balance;
      _pointsPerReferral = perRef;
      _pointsForFreeEntry = perEntry > 0 ? perEntry : _kDefaultPointsForFreeEntry;
      _usedProfileFallback = usedFallback;
      _loading = false;
    });
  }

  static int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  String _shareMessage(UserModel user) {
    return 'Join me on Veducation! Use my referral code ${user.referralCode} '
        'and we both earn rewards. '
        '($_pointsPerReferral loyalty points per successful referral, '
        '$_pointsForFreeEntry points = 1 free duel entry.)';
  }

  Future<void> _openExternalUri(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this app on your device.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong while opening the link.')),
      );
    }
  }

  Future<void> _shareWhatsApp(UserModel user) async {
    final text = Uri.encodeComponent(_shareMessage(user));
    await _openExternalUri(Uri.parse('https://wa.me/?text=$text'));
  }

  Future<void> _shareTelegram(UserModel user) async {
    final text = Uri.encodeComponent(_shareMessage(user));
    await _openExternalUri(
      Uri.parse('https://t.me/share/url?url=&text=$text'),
    );
  }

  Future<void> _shareFacebook(UserModel user) async {
    final q = Uri.encodeComponent(_shareMessage(user));
    await _openExternalUri(
      Uri.parse('https://www.facebook.com/sharer/sharer.php?u=https://veducation.app&quote=$q'),
    );
  }

  Future<void> _shareX(UserModel user) async {
    final text = Uri.encodeComponent(_shareMessage(user));
    await _openExternalUri(Uri.parse('https://twitter.com/intent/tweet?text=$text'));
  }

  Future<void> _shareInstagram(UserModel user) async {
    await Share.share(_shareMessage(user), subject: 'Veducation referral');
  }

  Future<void> _shareGeneric(UserModel user) async {
    await Share.share(_shareMessage(user), subject: 'Veducation referral');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Refer & Earn'),
            actions: [
              if (user != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _loadLoyaltyData,
                  tooltip: 'Refresh balance',
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadLoyaltyData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.card_giftcard, size: 56, color: Colors.blue),
                  const SizedBox(height: 12),
                  const Text(
                    'Invite friends, earn loyalty points, unlock free duel entries.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  if (user == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Sign in to see your referral code and loyalty balance.'),
                      ),
                    )
                  else ...[
                    if (_usedProfileFallback)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          child: const ListTile(
                            dense: true,
                            leading: Icon(Icons.cloud_off, color: Colors.amber),
                            title: Text(
                              'Could not refresh from server. Showing profile values.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    _LoyaltyRulesCard(
                      pointsPerReferral: _pointsPerReferral,
                      pointsForFreeEntry: _pointsForFreeEntry,
                    ),
                    const SizedBox(height: 12),
                    _BalanceProgressCard(
                      loading: _loading,
                      balance: _balancePoints,
                      pointsForFreeEntry: _pointsForFreeEntry,
                    ),
                    const SizedBox(height: 12),
                    _ReferralCodeCard(user: user),
                    const SizedBox(height: 12),
                    _ShareRow(
                      onWhatsApp: () => _shareWhatsApp(user),
                      onTelegram: () => _shareTelegram(user),
                      onInstagram: () => _shareInstagram(user),
                      onFacebook: () => _shareFacebook(user),
                      onX: () => _shareX(user),
                      onMore: () => _shareGeneric(user),
                    ),
                    const SizedBox(height: 12),
                    _HowItWorksCard(pointsPerReferral: _pointsPerReferral),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoyaltyRulesCard extends StatelessWidget {
  const _LoyaltyRulesCard({
    required this.pointsPerReferral,
    required this.pointsForFreeEntry,
  });

  final int pointsPerReferral;
  final int pointsForFreeEntry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loyalty rules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _ruleLine(Icons.person_add_alt_1, '$pointsPerReferral points per successful referral'),
            const SizedBox(height: 8),
            _ruleLine(Icons.emoji_events_outlined, '$pointsForFreeEntry points = 1 free duel entry'),
          ],
        ),
      ),
    );
  }

  static Widget _ruleLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.blue.shade700),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}

class _BalanceProgressCard extends StatelessWidget {
  const _BalanceProgressCard({
    required this.loading,
    required this.balance,
    required this.pointsForFreeEntry,
  });

  final bool loading;
  final int balance;
  final int pointsForFreeEntry;

  @override
  Widget build(BuildContext context) {
    final threshold = pointsForFreeEntry > 0 ? pointsForFreeEntry : _kDefaultPointsForFreeEntry;
    final freeEntries = balance ~/ threshold;
    final progressTowardNext = balance % threshold;
    final progress = threshold == 0 ? 0.0 : (progressTowardNext / threshold).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your balance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$balance',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('points', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  ),
                ],
              ),
            if (!loading) ...[
              const SizedBox(height: 8),
              Text(
                freeEntries > 0
                    ? 'You have enough points for $freeEntries free ${freeEntries == 1 ? 'entry' : 'entries'}.'
                    : 'Keep referring to unlock free entries.',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'Progress to next free entry ($progressTowardNext / $threshold)',
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  const _ReferralCodeCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your referral code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      user.referralCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: user.referralCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Referral code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share this code with friends so your rewards track correctly.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.onWhatsApp,
    required this.onTelegram,
    required this.onInstagram,
    required this.onFacebook,
    required this.onX,
    required this.onMore,
  });

  final VoidCallback onWhatsApp;
  final VoidCallback onTelegram;
  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onX;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share your code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Opens each app or website with your message ready.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ShareChip(label: 'WhatsApp', color: const Color(0xFF25D366), onTap: onWhatsApp),
                _ShareChip(label: 'Telegram', color: const Color(0xFF0088CC), onTap: onTelegram),
                _ShareChip(
                  label: 'Instagram',
                  color: const Color(0xFFE4405F),
                  onTap: onInstagram,
                  tooltip: 'Opens the system share sheet (choose Instagram if installed)',
                ),
                _ShareChip(label: 'Facebook', color: const Color(0xFF1877F2), onTap: onFacebook),
                _ShareChip(label: 'X', color: Colors.black87, onTap: onX),
                _ShareChip(label: 'More', color: Colors.blueGrey, onTap: onMore),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareChip extends StatelessWidget {
  const _ShareChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = ActionChip(
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 10,
        child: const SizedBox.shrink(),
      ),
      label: Text(label),
      onPressed: onTap,
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.pointsPerReferral});

  final int pointsPerReferral;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How it works',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _HowItWorksCard._buildStep('1', 'Share your referral code'),
            _HowItWorksCard._buildStep('2', 'Friend registers using your code'),
            _HowItWorksCard._buildStep(
              '3',
              'Earn $pointsPerReferral loyalty points per referral',
            ),
            _HowItWorksCard._buildStep('4', 'Redeem points for free duel entries'),
          ],
        ),
      ),
    );
  }

  static Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
