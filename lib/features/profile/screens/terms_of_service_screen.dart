import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../core/theme/app_theme.dart';

class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
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
                    Ionicons.calendar_outline,
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
              'Welcome to Bottles Up Vendor ("we," "our," or "us"). These Terms of Service ("Terms") govern your use of our vendor platform and services. By accessing or using our platform, you agree to be bound by these Terms.\n\nIf you do not agree to these Terms, please do not use our services.',
            ),

            _buildSection(
              theme,
              '2. Vendor Account',
              '2.1. Account Registration\nYou must provide accurate, current, and complete information during registration. You are responsible for maintaining the confidentiality of your account credentials.\n\n2.2. Account Eligibility\nTo use our platform, you must:\n• Be at least 18 years old\n• Have legal authority to operate a business\n• Possess all necessary licenses and permits\n• Comply with all local laws and regulations\n\n2.3. Account Responsibilities\nYou are responsible for all activities under your account. You must notify us immediately of any unauthorized access.',
            ),

            _buildSection(
              theme,
              '3. Services Provided',
              '3.1. Platform Features\nWe provide a platform for vendors to:\n• Create and manage events\n• List inventory and products\n• Receive and manage customer bookings\n• Process payments\n• Track analytics and performance\n\n3.2. Service Availability\nWe strive for 99.9% uptime but do not guarantee uninterrupted service. We reserve the right to modify, suspend, or discontinue services at any time.',
            ),

            _buildSection(
              theme,
              '4. Vendor Obligations',
              '4.1. Content Accuracy\nYou must ensure all information provided is accurate, including:\n• Event details and descriptions\n• Pricing and availability\n• Product specifications\n• Business information\n\n4.2. Quality Standards\nYou agree to:\n• Provide products as described\n• Maintain professional conduct\n• Respond to bookings within 24 hours\n• Honor all confirmed reservations\n• Maintain adequate inventory levels\n\n4.3. Prohibited Activities\nYou must not:\n• List illegal or prohibited items\n• Engage in fraudulent activities\n• Discriminate against customers\n• Manipulate ratings or reviews\n• Violate intellectual property rights\n• Circumvent platform fees',
            ),

            _buildSection(
              theme,
              '5. Fees and Payments',
              '5.1. Service Fees\nWe charge a 10% service fee on each booking. This fee covers:\n• Platform usage and maintenance\n• Payment processing\n• Customer support\n• Marketing and promotion\n\n5.2. Payment Processing\n• Customers pay at booking confirmation\n• Funds are held until event completion\n• Payouts occur within 3-5 business days after events\n• You are responsible for applicable taxes\n\n5.3. Refunds and Cancellations\nRefund policies are set by you but must be fair and clearly stated. We may process refunds on your behalf according to your policies.',
            ),

            _buildSection(
              theme,
              '6. Intellectual Property',
              '6.1. Your Content\nYou retain ownership of content you upload but grant us a license to use, display, and distribute it on our platform.\n\n6.2. Our Property\nAll platform features, designs, and trademarks are our property. You may not copy, modify, or reverse engineer our platform.\n\n6.3. Third-Party Content\nYou must have rights to all content you post. We are not liable for any copyright infringement you commit.',
            ),

            _buildSection(
              theme,
              '7. Liability and Disclaimers',
              '7.1. Limitation of Liability\nWe are not liable for:\n• Direct, indirect, or consequential damages\n• Lost profits or revenue\n• Service interruptions\n• Third-party actions\n• Customer disputes\n\n7.2. Service "As Is"\nOur platform is provided "as is" without warranties of any kind. We do not guarantee specific results or revenue.\n\n7.3. Indemnification\nYou agree to indemnify and hold us harmless from any claims arising from your use of the platform or violation of these Terms.',
            ),

            _buildSection(
              theme,
              '8. Data and Privacy',
              '8.1. Data Collection\nWe collect data as described in our Privacy Policy. You consent to our data practices by using our platform.\n\n8.2. Customer Data\nYou may access customer data for order fulfillment only. You must protect this data and comply with privacy laws.\n\n8.3. Data Security\nWe implement security measures but cannot guarantee absolute security. You are responsible for your account security.',
            ),

            _buildSection(
              theme,
              '9. Termination',
              '9.1. Termination Rights\nWe may suspend or terminate your account for:\n• Violation of these Terms\n• Fraudulent activity\n• Multiple customer complaints\n• Illegal activities\n• Non-payment of fees\n\n9.2. Effect of Termination\nUpon termination:\n• Access to the platform will be revoked\n• Pending payouts will be processed\n• You must fulfill existing commitments\n• Your data may be retained per our Privacy Policy',
            ),

            _buildSection(
              theme,
              '10. Dispute Resolution',
              '10.1. Customer Disputes\nYou are primarily responsible for resolving customer disputes. We may assist in mediation but are not required to do so.\n\n10.2. Arbitration\nDisputes between you and us will be resolved through binding arbitration rather than in court, except where prohibited by law.\n\n10.3. Class Action Waiver\nYou waive the right to participate in class action lawsuits against us.',
            ),

            _buildSection(
              theme,
              '11. General Provisions',
              '11.1. Amendments\nWe may modify these Terms at any time. Continued use constitutes acceptance of modified Terms.\n\n11.2. Governing Law\nThese Terms are governed by the laws of the United States and the State of Delaware.\n\n11.3. Severability\nIf any provision is found invalid, the remaining provisions remain in effect.\n\n11.4. Entire Agreement\nThese Terms constitute the entire agreement between you and us regarding platform use.',
            ),

            const SizedBox(height: 32),

            // Contact Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.darkCardDecoration,
              child: Column(
                children: [
                  Icon(
                    Ionicons.help_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Questions about our Terms?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contact our legal team at legal@bottlesup.com',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/support/contact');
                    },
                    child: const Text('Contact Support'),
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
