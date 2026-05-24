import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veducation_app/providers/auth_provider.dart';
import 'package:veducation_app/screens/contact/contact_constants.dart';
import 'package:veducation_app/screens/contact/my_tickets_screen.dart';
import 'package:veducation_app/services/api_service.dart';
import 'package:veducation_app/utils/app_theme.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _api = ApiService();
  final _ticketFormKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();

  final _ticketSubject = TextEditingController();
  final _ticketBody = TextEditingController();
  final _feedbackTitle = TextEditingController();
  final _feedbackBody = TextEditingController();

  String _feedbackCategory = 'suggestion';
  bool _submittingTicket = false;
  bool _submittingFeedback = false;

  @override
  void dispose() {
    _ticketSubject.dispose();
    _ticketBody.dispose();
    _feedbackTitle.dispose();
    _feedbackBody.dispose();
    super.dispose();
  }

  Future<void> _openUri(Uri uri, {String? noAppMessage}) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _toast(noAppMessage ?? 'Could not open link', isError: true);
      }
    } catch (_) {
      if (mounted) {
        _toast(noAppMessage ?? 'Could not open link', isError: true);
      }
    }
  }

  Future<void> _openMailto() async {
    final uri = Uri(
      scheme: 'mailto',
      path: ContactConstants.supportEmail,
      queryParameters: {'subject': ContactConstants.mailtoSubject},
    );
    await _openUri(
      uri,
      noAppMessage: 'No email app available. Address: ${ContactConstants.supportEmail}',
    );
  }

  void _toast(String msg, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: isError ? AppTheme.errorColor : AppTheme.secondaryColor,
      textColor: Colors.white,
    );
  }

  String _dioDetail(Object e) {
    if (e is DioException && e.response?.data is Map) {
      final d = e.response!.data as Map;
      if (d['detail'] != null) return d['detail'].toString();
    }
    return e.toString();
  }

  Future<void> _submitTicket() async {
    if (!_ticketFormKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _toast('Please log in to raise a ticket', isError: true);
      return;
    }
    setState(() => _submittingTicket = true);
    try {
      final res = await _api.createSupportTicket({
        'subject': _ticketSubject.text.trim(),
        'body': _ticketBody.text.trim(),
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        _ticketSubject.clear();
        _ticketBody.clear();
        _toast('Ticket submitted successfully');
      } else {
        _toast('Could not submit ticket', isError: true);
      }
    } catch (e) {
      _toast(_dioDetail(e), isError: true);
    } finally {
      if (mounted) setState(() => _submittingTicket = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (!_feedbackFormKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      _toast('Please log in to send feedback', isError: true);
      return;
    }
    setState(() => _submittingFeedback = true);
    try {
      final res = await _api.submitFeedback({
        'title': _feedbackTitle.text.trim(),
        'body': _feedbackBody.text.trim(),
        'category': _feedbackCategory,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        _feedbackTitle.clear();
        _feedbackBody.clear();
        setState(() => _feedbackCategory = 'suggestion');
        _toast('Thanks! Your feedback was sent');
      } else {
        _toast('Could not send feedback', isError: true);
      }
    } catch (e) {
      _toast(_dioDetail(e), isError: true);
    } finally {
      if (mounted) setState(() => _submittingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Us'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const MyTicketsScreen()),
              );
            },
            child: const Text(
              'My tickets',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Icon(
              Icons.contact_support,
              size: 56,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              'We are here to help',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Get in Touch',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    _ContactRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: ContactConstants.supportEmail,
                      onTap: _openMailto,
                    ),
                    const Divider(height: 24),
                    _ContactRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: ContactConstants.displayPhone,
                      onTap: () => _openUri(Uri(scheme: 'tel', path: ContactConstants.telE164)),
                    ),
                    const Divider(height: 24),
                    _ContactRow(
                      icon: Icons.language,
                      label: 'Website',
                      value: ContactConstants.websiteHost,
                      onTap: () => _openUri(Uri.parse(ContactConstants.websiteUrl)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Follow Us',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Facebook · Telegram · WhatsApp · YouTube',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SocialButton(
                          icon: Icons.thumb_up,
                          label: 'Facebook',
                          onTap: () => _openUri(Uri.parse(ContactConstants.facebookUrl)),
                        ),
                        _SocialButton(
                          icon: Icons.send,
                          label: 'Telegram',
                          onTap: () => _openUri(Uri.parse(ContactConstants.telegramUrl)),
                        ),
                        _SocialButton(
                          icon: Icons.chat,
                          label: 'WhatsApp',
                          onTap: () => _openUri(Uri.parse(ContactConstants.whatsappUrl)),
                        ),
                        _SocialButton(
                          icon: Icons.play_circle_filled,
                          label: 'YouTube',
                          onTap: () => _openUri(Uri.parse(ContactConstants.youtubeUrl)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _ticketFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Raise a ticket',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Describe your issue. Our team will follow up by email or phone.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ticketSubject,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          hintText: 'Short summary of the issue',
                        ),
                        maxLength: 200,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length < 3) return 'Enter at least 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ticketBody,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText: 'What happened? Include steps if relevant.',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        maxLength: 8000,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length < 10) return 'Please add more detail (min 10 characters)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _submittingTicket ? null : _submitTicket,
                        child: _submittingTicket
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit ticket'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _feedbackFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Feedback / Suggestion',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share ideas, report bugs, or request features.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _feedbackCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: const [
                          DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
                          DropdownMenuItem(value: 'bug', child: Text('Bug report')),
                          DropdownMenuItem(value: 'feature_request', child: Text('Feature request')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _feedbackCategory = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _feedbackTitle,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Headline for your feedback',
                        ),
                        maxLength: 200,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length < 3) return 'Enter at least 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _feedbackBody,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText: 'Tell us more…',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        maxLength: 8000,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.length < 10) return 'Please add more detail (min 10 characters)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _submittingFeedback ? null : _submitFeedback,
                        child: _submittingFeedback
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send feedback'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 24),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
