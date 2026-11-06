import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/bu_kit.dart';
import '../../owner/logic/owner_rules.dart' show siteUrl;
import '../../workspace/providers/workspace_providers.dart' show urlOpenerProvider;
import '../logic/business_status.dart';
import '../providers/business_providers.dart';

/// "Awaiting verification" (brief 15 Oct, sections 4 and 5): at the top of an owner's and an organizer's Overview, where the business stands, what the
/// person can do now and what waits for approval, with the way to fix it on the website. Shown only while the business is not verified. If the
/// state cannot be read the card is simply absent: it never says "verified" or "not submitted" without knowing.
class BusinessStatusCard extends ConsumerWidget {
  const BusinessStatusCard({super.key, required this.orgId, this.site});

  final String orgId;

  /// The website's address; the build's own by default.
  final String? site;

  Uri _businessPage() => Uri.parse('${(site ?? siteUrl).replaceAll(RegExp(r'/+$'), '')}/business/$orgId/onboarding');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(businessStatusProvider(orgId)).valueOrNull;
    if (!showsStatusCard(status)) return const SizedBox.shrink();
    final b = status!;
    final theme = Theme.of(context);
    final todo = describeMissing(b.missing);
    final actions = whatYouCanDo(b);
    final warning = b.state == VerificationState.moreInformationNeeded;

    final bu = context.bu;
    return BuCard(
      key: const Key('business-status-card'),
      margin: const EdgeInsets.only(bottom: BuSpace.l),
      highlight: warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BuStatusPill(
                b.state.label,
                key: const Key('business-status-label'),
                tone: warning ? BuTone.attention : BuTone.brand,
              ),
              const SizedBox(width: BuSpace.s),
              Expanded(
                child: Text(
                  b.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(b.state.summary, key: const Key('business-status-summary')),
          if (b.requestMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              'From the reviewer: ${b.requestMessage}',
              key: const Key('business-status-request'),
            ),
          ],
          if (todo.isNotEmpty && b.state != VerificationState.underReview) ...[
            const SizedBox(height: 8),
            Text(
              'Still to do before you can submit:',
              style: theme.textTheme.labelLarge,
            ),
            for (final t in todo)
              Text('• $t', key: Key('business-missing-${todo.indexOf(t)}')),
          ],
          const SizedBox(height: 8),
          for (final c in actions.can)
            Text(
              '✓ $c',
              style: theme.textTheme.bodySmall?.copyWith(color: bu.soft),
            ),
          for (final w in actions.waits)
            Text(
              '… $w waits until the business is verified',
              key: const Key('business-status-waits'),
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('business-status-open'),
            onPressed: () async {
              var opened = false;
              try {
                opened = await ref.read(urlOpenerProvider)(_businessPage());
              } catch (_) {
                opened = false;
              }
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not open the website. Go to ${_businessPage()} in your browser.',
                    ),
                  ),
                );
              }
            },
            child: Text(
              b.state == VerificationState.underReview
                  ? 'See progress on the website'
                  : 'Open business details on the website',
            ),
          ),
        ],
      ),
    );
  }
}
