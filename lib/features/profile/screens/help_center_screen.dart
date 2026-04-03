import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import '../../../core/theme/app_theme.dart';

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<FAQItem> _faqs = [
    FAQItem(
      category: 'Getting Started',
      question: 'How do I create my first event?',
      answer: 'To create an event:\n\n1. Tap on the "Events" tab in the bottom navigation\n2. Click the "+" button in the top right\n3. Fill in event details (name, date, venue, etc.)\n4. Add inventory items for the event\n5. Set pricing and availability\n6. Tap "Create Event" to publish\n\nYour event will be visible to customers immediately!',
    ),
    FAQItem(
      category: 'Getting Started',
      question: 'How do I manage my inventory?',
      answer: 'Navigate to the Inventory section from the bottom menu. Here you can:\n\n• Add new bottles and items\n• Update quantities\n• Set minimum stock alerts\n• Track low stock items\n• Update pricing\n• View inventory history\n\nYou\'ll receive notifications when items are running low.',
    ),
    FAQItem(
      category: 'Bookings',
      question: 'How do I view and manage bookings?',
      answer: 'Go to the Bookings tab to:\n\n• View all customer bookings\n• Filter by status (pending, confirmed, completed, cancelled)\n• Accept or reject booking requests\n• View customer details\n• Track booking revenue\n• Export booking reports\n\nYou\'ll get instant notifications for new bookings.',
    ),
    FAQItem(
      category: 'Bookings',
      question: 'What happens when I receive a booking?',
      answer: 'When a customer makes a booking:\n\n1. You receive a push notification\n2. The booking appears in your Bookings tab as "Pending"\n3. Review the booking details\n4. Accept or reject within 24 hours\n5. Once accepted, inventory is reserved\n6. Customer receives confirmation\n\nAlways respond promptly to maintain good ratings!',
    ),
    FAQItem(
      category: 'Events',
      question: 'Can I edit an event after publishing?',
      answer: 'Yes! You can edit events at any time:\n\n• Go to Events tab\n• Tap on the event you want to edit\n• Click the edit icon (pencil)\n• Make your changes\n• Save updates\n\nNote: If there are existing bookings, some changes (like reducing inventory) may be restricted to protect confirmed bookings.',
    ),
    FAQItem(
      category: 'Events',
      question: 'How do I cancel or delete an event?',
      answer: 'To cancel an event:\n\n1. Open the event details\n2. Tap the menu (three dots)\n3. Select "Cancel Event"\n4. Choose a reason\n5. Confirm cancellation\n\nCustomers with bookings will be notified automatically. Refunds will be processed according to your cancellation policy.',
    ),
    FAQItem(
      category: 'Payments',
      question: 'When do I receive payment?',
      answer: 'Payment timeline:\n\n• Customer pays when booking is confirmed\n• Funds are held securely\n• Payment released to you after event completion\n• Transfer to your bank account within 3-5 business days\n• View all transactions in Payment Methods section\n\nYou can track pending and completed payments in your dashboard.',
    ),
    FAQItem(
      category: 'Payments',
      question: 'What are the service fees?',
      answer: 'Our transparent pricing:\n\n• 10% service fee on each booking\n• No monthly subscription fees\n• No hidden charges\n• Payment processing included\n\nYou only pay when you earn. The fee covers:\n• Platform maintenance\n• Payment processing\n• Customer support\n• Marketing to customers',
    ),
    FAQItem(
      category: 'Account',
      question: 'How do I update my business information?',
      answer: 'To update your details:\n\n1. Go to Profile tab\n2. Tap "Business Details"\n3. Edit any information\n4. Save changes\n\nYou can update:\n• Business name\n• Contact information\n• Operating hours\n• Business address\n• Payment methods',
    ),
    FAQItem(
      category: 'Account',
      question: 'How do I improve my vendor rating?',
      answer: 'Boost your rating by:\n\n• Responding quickly to bookings\n• Providing accurate event details\n• Maintaining good inventory levels\n• Being professional with customers\n• Honoring all confirmed bookings\n• Resolving issues promptly\n\nHigher ratings lead to more visibility and bookings!',
    ),
    FAQItem(
      category: 'Troubleshooting',
      question: 'I\'m not receiving notifications',
      answer: 'To fix notification issues:\n\n1. Go to Profile > Notifications\n2. Enable push notifications\n3. Check your phone settings:\n   • iOS: Settings > Bottles Up Vendor > Notifications\n   • Android: Settings > Apps > Bottles Up Vendor > Notifications\n4. Ensure "Do Not Disturb" is off\n5. Try logging out and back in\n\nStill having issues? Contact support.',
    ),
    FAQItem(
      category: 'Troubleshooting',
      question: 'What if I have a dispute with a customer?',
      answer: 'For disputes:\n\n1. Try to resolve directly with the customer first\n2. Document all communication\n3. If unresolved, contact our support team\n4. Provide booking details and evidence\n5. Our team will mediate fairly\n\nWe review each case individually and make decisions based on our policies and evidence provided.',
    ),
  ];

  List<FAQItem> get _filteredFaqs {
    if (_searchQuery.isEmpty) {
      return _faqs;
    }
    return _faqs.where((faq) {
      final query = _searchQuery.toLowerCase();
      return faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.category.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, List<FAQItem>> get _groupedFaqs {
    final filtered = _filteredFaqs;
    final Map<String, List<FAQItem>> grouped = {};
    for (var faq in filtered) {
      if (!grouped.containsKey(faq.category)) {
        grouped[faq.category] = [];
      }
      grouped[faq.category]!.add(faq);
    }
    return grouped;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedFaqs = _groupedFaqs;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for help...',
                prefixIcon: const Icon(Ionicons.search_outline),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Ionicons.close_circle),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Quick Actions
          if (_searchQuery.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: AppTheme.darkCardDecoration,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Ionicons.chatbubbles_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Contact Support',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Get help from our team',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Ionicons.chevron_forward,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/support/contact');
                      },
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Ionicons.book_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Video Tutorials',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Learn with step-by-step guides',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Icon(
                        Ionicons.chevron_forward,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Video Tutorials - Coming Soon')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // FAQs
          Expanded(
            child: groupedFaqs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Ionicons.search_outline,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try different keywords',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: groupedFaqs.length,
                    itemBuilder: (context, index) {
                      final category = groupedFaqs.keys.elementAt(index);
                      final faqs = groupedFaqs[category]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_searchQuery.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                              child: Text(
                                category,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                          ...faqs.map((faq) => _buildFAQItem(context, faq)),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, FAQItem faq) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.darkCardDecoration,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            faq.question,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Ionicons.help_circle_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          children: [
            Text(
              faq.answer,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQItem {
  final String category;
  final String question;
  final String answer;

  FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}
