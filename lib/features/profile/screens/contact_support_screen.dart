import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plain_error.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../logic/site_contact.dart';
import '../providers/site_contact_provider.dart';

/// Opens a web, mail or phone address. Returns whether the phone had something to open it with. Replaced in tests.
typedef LinkOpener = Future<bool> Function(Uri uri);

final contactLinkOpenerProvider = Provider<LinkOpener>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// Contact Support: how to reach BottlesUp, as the BottlesUp team has set it in the CMS (e-mail, phone), and a message that opens ready in the person's own mail app. Nothing is sent from
/// here and nothing is promised: there is no ticket system behind this screen, no live chat and no round-the-clock line, so none is claimed. A contact the team has not filled in is not shown.
class ContactSupportScreen extends ConsumerStatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  ConsumerState<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends ConsumerState<ContactSupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'General question';
  String? _problem;

  static const _categories = ['General question', 'Technical issue', 'Booking problem', 'Payment issue', 'Account question', 'Feature request', 'Other'];

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri, String failure) async {
    bool opened;
    try {
      opened = await ref.read(contactLinkOpenerProvider)(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  Future<void> _write(SiteContact contact) async {
    final problem = validateSupportMessage(subject: _subject.text, message: _message.text);
    setState(() => _problem = problem);
    if (problem != null || contact.email == null) return;
    final user = ref.read(currentVendorUserProvider);
    final uri = supportMailto(contact.email!, category: _category, subject: _subject.text, message: _message.text, from: user?.email);
    await _open(uri, 'No email app could be opened. You can write to ${contact.email} yourself.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contact = ref.watch(siteContactProvider);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.w600)), backgroundColor: Colors.transparent, elevation: 0),
      body: contact.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(couldNotLoad('our contact details', e), key: const Key('contact-error'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(key: const Key('contact-retry'), onPressed: () => ref.invalidate(siteContactProvider), child: const Text('Try again')),
            ]),
          ),
        ),
        data: (c) => _body(theme, c),
      ),
    );
  }

  Widget _body(ThemeData theme, SiteContact c) {
    final user = ref.watch(currentVendorUserProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.hasEmail || c.hasPhone)
            Container(
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  if (c.hasEmail)
                    ListTile(
                      key: const Key('contact-email'),
                      leading: const Icon(Ionicons.mail_outline),
                      title: const Text('Email'),
                      subtitle: Text(c.email!),
                      trailing: const Icon(Ionicons.chevron_forward, size: 18),
                      onTap: () => _open(Uri(scheme: 'mailto', path: c.email), 'No email app could be opened. You can write to ${c.email} yourself.'),
                    ),
                  if (c.hasEmail && c.hasPhone) const Divider(height: 1),
                  if (c.hasPhone)
                    ListTile(
                      key: const Key('contact-phone'),
                      leading: const Icon(Ionicons.call_outline),
                      title: const Text('Phone'),
                      subtitle: Text(c.phone!),
                      trailing: const Icon(Ionicons.chevron_forward, size: 18),
                      onTap: () => _open(telUri(c.phone!)!, 'This device cannot place a call. The number is ${c.phone}.'),
                    ),
                ],
              ),
            )
          else
            Text('BottlesUp has not published a contact address or phone number yet.', key: const Key('contact-none'), style: theme.textTheme.bodyLarge),
          if (c.hasEmail) ...[
            const SizedBox(height: 24),
            Text('Write to us', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('This opens an email in your own mail app, ready to send. Nothing is sent from here.', key: const Key('contact-write-note'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.email ?? '', key: const Key('contact-from'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('contact-category'),
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Topic', border: OutlineInputBorder()),
                    items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                  const SizedBox(height: 16),
                  TextField(key: const Key('contact-subject'), controller: _subject, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('contact-message'),
                    controller: _message,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true, border: OutlineInputBorder()),
                  ),
                  if (_problem != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_problem!, key: const Key('contact-problem'), style: TextStyle(color: theme.colorScheme.error))),
                  const SizedBox(height: 16),
                  FilledButton.icon(key: const Key('contact-write'), onPressed: () => _write(c), icon: const Icon(Ionicons.mail_outline), label: const Text('Open my email app')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
