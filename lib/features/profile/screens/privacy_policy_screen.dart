import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Updated
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Ionicons.shield_checkmark_outline,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last Updated: January 2025',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              theme,
              '1. Introduction',
              'Bottles Up ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our vendor platform.\n\nBy using our services, you consent to the data practices described in this policy.',
            ),

            _buildSection(
              theme,
              '2. Information We Collect',
              '2.1. Account Information\nWhen you register as a vendor, we collect:\n• Full name and business name\n• Email address and phone number\n• Business address and location\n• Tax identification information\n• Banking and payment details\n• Profile photos and business logos\n\n2.2. Business Information\n• Event listings and descriptions\n• Inventory and product details\n• Pricing and availability\n• Operating hours and policies\n• Business licenses and certifications\n\n2.3. Transaction Data\n• Booking details and history\n• Payment transactions\n• Refund and cancellation records\n• Customer communication logs\n• Financial reports and analytics\n\n2.4. Technical Information\n• IP address and device information\n• Browser type and version\n• Operating system\n• Location data\n• App usage patterns and analytics\n• Crash reports and error logs',
            ),

            _buildSection(
              theme,
              '3. How We Use Your Information',
              'We use collected information to:\n\n3.1. Provide Services\n• Create and manage your account\n• Process bookings and payments\n• Facilitate customer communication\n• Generate analytics and reports\n• Provide customer support\n\n3.2. Improve Our Platform\n• Enhance user experience\n• Develop new features\n• Conduct research and analysis\n• Fix bugs and technical issues\n• Optimize performance\n\n3.3. Communication\n• Send booking notifications\n• Provide account updates\n• Share promotional content (with consent)\n• Send administrative messages\n• Request feedback and reviews\n\n3.4. Security and Compliance\n• Detect and prevent fraud\n• Enforce our Terms of Service\n• Comply with legal obligations\n• Resolve disputes\n• Protect user safety',
            ),

            _buildSection(
              theme,
              '4. Information Sharing',
              '4.1. With Customers\nWe share necessary information with customers for:\n• Booking confirmations\n• Event details and locations\n• Contact information for coordination\n• Business verification\n\n4.2. With Service Providers\nWe may share data with:\n• Payment processors (Stripe, PayPal)\n• Cloud storage providers (AWS, Firebase)\n• Analytics services (Google Analytics)\n• Email service providers\n• Customer support tools\n\n4.3. For Legal Reasons\nWe may disclose information:\n• To comply with legal obligations\n• In response to court orders or subpoenas\n• To protect our rights and property\n• To prevent fraud or illegal activities\n• In connection with business transfers\n\n4.4. With Your Consent\nWe may share information for purposes you explicitly approve.',
            ),

            _buildSection(
              theme,
              '5. Data Security',
              '5.1. Security Measures\nWe implement industry-standard security:\n• Encryption of data in transit (TLS/SSL)\n• Encryption of sensitive data at rest\n• Secure authentication systems\n• Regular security audits\n• Access controls and monitoring\n• Secure backup systems\n\n5.2. Your Responsibility\nYou must:\n• Keep login credentials confidential\n• Use strong, unique passwords\n• Enable two-factor authentication\n• Report suspicious activity immediately\n• Secure your devices and network\n\n5.3. No Absolute Security\nWhile we strive to protect your data, no system is completely secure. We cannot guarantee absolute security.',
            ),

            _buildSection(
              theme,
              '6. Your Rights and Choices',
              '6.1. Access and Correction\nYou can:\n• Access your personal information\n• Update or correct inaccuracies\n• Download your data\n• Request data portability\n\n6.2. Deletion Rights\nYou may request deletion of your account and data, subject to:\n• Completion of active bookings\n• Resolution of pending issues\n• Legal retention requirements\n• Financial record obligations\n\n6.3. Communication Preferences\nYou can:\n• Opt out of marketing emails\n• Adjust notification settings\n• Control data sharing preferences\n• Manage cookie settings\n\n6.4. Do Not Sell\nWe do not sell your personal information to third parties.',
            ),

            _buildSection(
              theme,
              '7. Data Retention',
              'We retain your information:\n\n• Account data: Duration of account plus 7 years\n• Transaction records: 7 years for tax purposes\n• Communication logs: 3 years\n• Technical logs: 90 days\n• Marketing data: Until you opt out\n\nRetention periods may be extended for legal compliance or dispute resolution.',
            ),

            _buildSection(
              theme,
              '8. International Data Transfers',
              'Your information may be transferred to and processed in:\n• United States (primary servers)\n• European Union (backup servers)\n• Other countries where our service providers operate\n\nWe ensure appropriate safeguards for international transfers.',
            ),

            _buildSection(
              theme,
              '9. Children\'s Privacy',
              'Our services are not intended for individuals under 18. We do not knowingly collect data from minors. If we discover such collection, we will delete it promptly.',
            ),

            _buildSection(
              theme,
              '10. Cookies and Tracking',
              '10.1. Types of Cookies\n• Essential cookies (required for functionality)\n• Analytics cookies (usage tracking)\n• Preference cookies (user settings)\n• Marketing cookies (advertising)\n\n10.2. Your Choices\nYou can control cookies through:\n• Browser settings\n• Cookie consent manager\n• Opt-out tools\n\nDisabling cookies may limit functionality.',
            ),

            _buildSection(
              theme,
              '11. Third-Party Links',
              'Our platform may contain links to third-party websites. We are not responsible for their privacy practices. Please review their policies.',
            ),

            _buildSection(
              theme,
              '12. Changes to This Policy',
              'We may update this Privacy Policy periodically. Material changes will be communicated via:\n• Email notification\n• In-app announcements\n• Website banners\n\nContinued use after changes constitutes acceptance.',
            ),

            _buildSection(
              theme,
              '13. Contact Information',
              'For privacy-related questions or requests:\n\nEmail: privacy@bottlesup.com\nPhone: +1-800-BOTTLES\nMail: Bottles Up Privacy Team\n       123 Main Street\n       New York, NY 10001\n\nData Protection Officer: dpo@bottlesup.com',
            ),

            const SizedBox(height: 32),

            // Privacy Commitment
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  Icon(
                    Ionicons.lock_closed_outline,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Privacy Matters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We are committed to protecting your personal information and being transparent about our data practices.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/support/contact');
                        },
                        child: const Text('Contact Privacy Team'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
