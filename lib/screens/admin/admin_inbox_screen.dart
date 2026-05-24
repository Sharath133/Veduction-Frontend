import 'package:flutter/material.dart';
import 'package:veducation_app/services/api_service.dart';

class AdminInboxScreen extends StatefulWidget {
  const AdminInboxScreen({super.key});

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _api = ApiService();
  List<dynamic> _tickets = [];
  List<dynamic> _feedback = [];
  bool _tLoading = true;
  bool _fLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadTickets();
    _loadFeedback();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _tLoading = true);
    try {
      final res = await _api.adminListSupportTickets();
      if (res.statusCode == 200) {
        setState(() {
          _tickets = res.data['tickets'] ?? [];
          _tLoading = false;
        });
      }
    } catch (_) {
      setState(() => _tLoading = false);
    }
  }

  Future<void> _loadFeedback() async {
    setState(() => _fLoading = true);
    try {
      final res = await _api.adminListFeedback();
      if (res.statusCode == 200) {
        setState(() {
          _feedback = res.data['items'] ?? [];
          _fLoading = false;
        });
      }
    } catch (_) {
      setState(() => _fLoading = false);
    }
  }

  Future<void> _setTicketStatus(String id, String status) async {
    try {
      await _api.adminUpdateSupportTicketStatus(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
        _loadTickets();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _ticketActions(Map<String, dynamic> t) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('${t['subject']}')),
            const Divider(),
            for (final s in ['open', 'in_progress', 'resolved', 'closed'])
              ListTile(
                title: Text('Set status: $s'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setTicketStatus(t['id'].toString(), s);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Tickets'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          RefreshIndicator(
            onRefresh: _loadTickets,
            child: _tLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _tickets.length,
                    itemBuilder: (_, i) {
                      final t = _tickets[i] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text('${t['subject']}'),
                          subtitle: Text(
                            '${t['user_mobile'] ?? ''}\n${t['body']}',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Chip(label: Text('${t['status']}')),
                          onTap: () => _ticketActions(t),
                        ),
                      );
                    },
                  ),
          ),
          RefreshIndicator(
            onRefresh: _loadFeedback,
            child: _fLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _feedback.length,
                    itemBuilder: (_, i) {
                      final f = _feedback[i] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text('${f['title']}'),
                          subtitle: Text(
                            '${f['user_mobile'] ?? ''} · ${f['category']}\n${f['body']}',
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
