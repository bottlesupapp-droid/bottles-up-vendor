import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supabase_auth_provider.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  final Map<String, String> userData;

  const RoleSelectionScreen({
    super.key,
    required this.userData,
  });

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  String? _selectedRole;

  final List<Map<String, dynamic>> _roles = [
    {
      'id': 'venue_owner',
      'title': 'Venue Owner',
      'description': 'I own or manage a venue/club',
      'icon': Icons.store,
      'color': Colors.purple,
    },
    {
      'id': 'organizer',
      'title': 'Organizer',
      'description': 'I organize and host events',
      'icon': Icons.event,
      'color': Colors.blue,
    },
    {
      'id': 'promoter',
      'title': 'Promoter',
      'description': 'I promote events and sell tickets',
      'icon': Icons.campaign,
      'color': Colors.orange,
    },
    {
      'id': 'staff',
      'title': 'Staff',
      'description': 'I work for a venue or event',
      'icon': Icons.work,
      'color': Colors.green,
    },
  ];

  Future<void> _continueWithRole() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create user account with selected role
    await ref.read(supabaseAuthProvider.notifier).register(
      email: widget.userData['email']!,
      password: widget.userData['password']!,
      name: widget.userData['name']!,
      vendorType: _selectedRole,
    );

    // The auth listener will handle navigation to role-specific onboarding
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(supabaseAuthProvider);

    // Listen to auth errors
    ref.listen<String?>(authErrorProvider, (previous, next) {
      if (next != null) {
        if (next == 'DATABASE_SETUP_REQUIRED') {
          context.go('/database-setup');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
        ref.read(supabaseAuthProvider.notifier).clearError();
      }
    });

    // Navigate to role-specific onboarding after registration
    ref.listen<bool>(isAuthenticatedProvider, (previous, next) {
      if (next) {
        // Router redirect will handle navigation to onboarding
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Who are you?',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Select your role to continue',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Role Cards Grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _roles.length,
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    final isSelected = _selectedRole == role['id'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRole = role['id'];
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? role['color'].withOpacity(0.1)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? role['color']
                                : theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: role['color'].withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  role['icon'],
                                  size: 32,
                                  color: role['color'],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Title
                              Text(
                                role['title'],
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? role['color']
                                      : theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 8),

                              // Description
                              Text(
                                role['description'],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 8),

                              // Checkmark
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: role['color'],
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _continueWithRole,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
