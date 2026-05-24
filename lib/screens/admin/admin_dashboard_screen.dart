import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:veducation_app/screens/admin/admin_duels_screen.dart';
import 'package:veducation_app/screens/admin/admin_inbox_screen.dart';
import 'package:veducation_app/screens/admin/admin_instructions_screen.dart';
import 'package:veducation_app/screens/admin/admin_pyqs_screen.dart';
import 'package:veducation_app/screens/admin/admin_rankers_screen.dart';
import 'package:veducation_app/screens/admin/admin_users_screen.dart';
import 'package:veducation_app/services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _stats;
  List<dynamic> _daily = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  String _money(dynamic v) {
    if (v == null) return '0.00';
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n.toStringAsFixed(2);
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final overview = await _api.adminGetStats();
      final daily = await _api.adminGetDailyStats(days: 14);
      if (mounted && overview.statusCode == 200 && daily.statusCode == 200) {
        setState(() {
          _stats = overview.data as Map<String, dynamic>;
          _daily = daily.data['series'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiService.errorMessage(e))),
        );
      }
    }
  }

  Widget _dailyTable() {
    if (_daily.isEmpty) {
      return const Text('No daily series');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Users')),
          DataColumn(label: Text('Regs')),
          DataColumn(label: Text('Reg ₹')),
          DataColumn(label: Text('Pay #')),
          DataColumn(label: Text('Pay ₹')),
        ],
        rows: _daily.map((raw) {
          final m = raw as Map<String, dynamic>;
          return DataRow(
            cells: [
              DataCell(Text('${m['date']}')),
              DataCell(Text('${m['new_users']}')),
              DataCell(Text('${m['completed_registrations']}')),
              DataCell(Text(_money(m['registration_revenue']))),
              DataCell(Text('${m['completed_payments_count']}')),
              DataCell(Text(_money(m['payments_revenue']))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _lineChart({
    required String title,
    required String yKey,
    required Color color,
  }) {
    if (_daily.isEmpty) return const SizedBox.shrink();
    final spots = <FlSpot>[];
    double maxY = 1;
    for (var i = 0; i < _daily.length; i++) {
      final m = _daily[i] as Map<String, dynamic>;
      final y = (m[yKey] as num?)?.toDouble() ?? 0;
      if (y > maxY) maxY = y;
      spots.add(FlSpot(i.toDouble(), y));
    }
    maxY *= 1.15;
    if (maxY < 1) maxY = 1;

    return SizedBox(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (_daily.length - 1).toDouble().clamp(0, double.infinity),
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.round();
                        if (i < 0 || i >= _daily.length) {
                          return const SizedBox.shrink();
                        }
                        final d = (_daily[i] as Map)['date'].toString();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            d.length >= 10 ? d.substring(5, 10) : d,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v == v.roundToDouble()
                            ? '${v.toInt()}'
                            : v.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Admin Portal',
                  style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.quiz),
              title: const Text('Daily Duels'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminDuelsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events),
              title: const Text('Top rankers'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminRankersScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Instructions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminInstructionsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.inbox),
              title: const Text('Inbox'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminInboxScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('PYQs'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminPYQsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminUsersScreen()));
              },
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Overview',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _StatCard('Users', '${_stats?['total_users'] ?? 0}',
                          Icons.people, Colors.blue),
                      _StatCard('Duels', '${_stats?['total_duels'] ?? 0}',
                          Icons.quiz, Colors.green),
                      _StatCard(
                          'Regs',
                          '${_stats?['total_registrations'] ?? 0}',
                          Icons.how_to_reg,
                          Colors.orange),
                      _StatCard('Attempts', '${_stats?['total_attempts'] ?? 0}',
                          Icons.assignment, Colors.purple),
                      _StatCard(
                          'Today regs',
                          '${_stats?['today_registrations'] ?? 0}',
                          Icons.today,
                          Colors.teal),
                      _StatCard(
                          'Today attempts',
                          '${_stats?['today_attempts'] ?? 0}',
                          Icons.trending_up,
                          Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total revenue',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${_money(_stats?['total_revenue'])}',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Last 14 days — registrations & revenue',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _dailyTable(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _lineChart(
                        title: 'Completed registrations / day',
                        yKey: 'completed_registrations',
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _lineChart(
                        title: 'Payments revenue / day (₹)',
                        yKey: 'payments_revenue',
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
