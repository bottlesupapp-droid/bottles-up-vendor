import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../models/event_team_member.dart';

class ManageLineupScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventName;

  const ManageLineupScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  ConsumerState<ManageLineupScreen> createState() => _ManageLineupScreenState();
}

class _ManageLineupScreenState extends ConsumerState<ManageLineupScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<EventTeamMember> _teamMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('event_team_members')
          .select()
          .eq('event_id', widget.eventId)
          .order('created_at', ascending: true);

      setState(() {
        _teamMembers = (response as List)
            .map((json) => EventTeamMember.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load team members: $e')),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({EventTeamMember? existingMember}) async {
    final nameController = TextEditingController(text: existingMember?.name ?? '');
    final emailController = TextEditingController(text: existingMember?.email ?? '');
    final phoneController = TextEditingController(text: existingMember?.phone ?? '');
    String selectedRole = existingMember?.role ?? TeamRole.dj;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingMember == null ? 'Add Team Member' : 'Edit Team Member'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      hintText: 'Enter name',
                      prefixIcon: Icon(Ionicons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role *',
                      prefixIcon: Icon(Ionicons.briefcase_outline),
                    ),
                    items: TeamRole.allRoles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            Icon(_getRoleIcon(role), size: 18),
                            const SizedBox(width: 8),
                            Text(role),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedRole = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'email@example.com',
                      prefixIcon: Icon(Ionicons.mail_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '+1 234 567 8900',
                      prefixIcon: Icon(Ionicons.call_outline),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _saveMember(
                    existingMember: existingMember,
                    name: nameController.text.trim(),
                    role: selectedRole,
                    email: emailController.text.trim().isEmpty
                        ? null
                        : emailController.text.trim(),
                    phone: phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                  );
                }
              },
              child: Text(existingMember == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMember({
    EventTeamMember? existingMember,
    required String name,
    required String role,
    String? email,
    String? phone,
  }) async {
    try {
      if (existingMember == null) {
        // Create new member
        final memberData = {
          'event_id': widget.eventId,
          'name': name,
          'role': role,
          'email': email,
          'phone': phone,
        };
        await _supabase.from('event_team_members').insert(memberData);
      } else {
        // Update existing member
        final memberData = {
          'name': name,
          'role': role,
          'email': email,
          'phone': phone,
          'updated_at': DateTime.now().toIso8601String(),
        };
        await _supabase
            .from('event_team_members')
            .update(memberData)
            .eq('id', existingMember.id);
      }

      await _loadTeamMembers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingMember == null
                  ? 'Team member added successfully!'
                  : 'Team member updated successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save team member: $e')),
        );
      }
    }
  }

  Future<void> _deleteMember(EventTeamMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team Member'),
        content: Text('Are you sure you want to remove "${member.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('event_team_members').delete().eq('id', member.id);
        await _loadTeamMembers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team member removed successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove team member: $e')),
          );
        }
      }
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case TeamRole.dj:
        return Ionicons.musical_notes_outline;
      case TeamRole.coordinator:
        return Ionicons.clipboard_outline;
      case TeamRole.security:
        return Ionicons.shield_checkmark_outline;
      case TeamRole.bartender:
        return Ionicons.beer_outline;
      case TeamRole.host:
        return Ionicons.megaphone_outline;
      case TeamRole.manager:
        return Ionicons.business_outline;
      case TeamRole.photographer:
        return Ionicons.camera_outline;
      default:
        return Ionicons.person_outline;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case TeamRole.dj:
        return Colors.purple;
      case TeamRole.coordinator:
        return Colors.blue;
      case TeamRole.security:
        return Colors.orange;
      case TeamRole.bartender:
        return Colors.teal;
      case TeamRole.host:
        return Colors.pink;
      case TeamRole.manager:
        return Colors.indigo;
      case TeamRole.photographer:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  List<EventTeamMember> _getMembersByRole(String role) {
    return _teamMembers.where((m) => m.role == role).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final djCount = _getMembersByRole(TeamRole.dj).length;
    final otherMembers = _teamMembers.where((m) => m.role != TeamRole.dj).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Event Team'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Ionicons.add_circle_outline),
            tooltip: 'Add Team Member',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeamMembers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Info Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.darkContainerDecoration,
                      child: Row(
                        children: [
                          Icon(
                            Ionicons.calendar_outline,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.eventName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_teamMembers.length} team member${_teamMembers.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // DJs / Performers Section
                    Row(
                      children: [
                        Icon(
                          Ionicons.musical_notes_outline,
                          color: Colors.purple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DJs & Performers ($djCount)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showAddEditDialog(),
                          icon: const Icon(Ionicons.add_outline, size: 20),
                          tooltip: 'Add DJ/Performer',
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (_getMembersByRole(TeamRole.dj).isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: AppTheme.darkCardDecoration,
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Ionicons.musical_notes_outline,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No DJs added yet',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Ionicons.add_outline),
                                label: const Text('Add DJ'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._getMembersByRole(TeamRole.dj).map((dj) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildMemberCard(dj, highlight: true),
                          )),

                    const SizedBox(height: 32),

                    // Other Team Members Section
                    if (otherMembers.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Ionicons.people_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Other Team Members (${otherMembers.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...otherMembers.map((member) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildMemberCard(member),
                          )),
                    ],

                    if (_teamMembers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            children: [
                              Icon(
                                Ionicons.people_outline,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No team members yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Ionicons.add_outline),
                                label: const Text('Add Team Member'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: _teamMembers.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditDialog(),
              child: const Icon(Ionicons.add_outline),
            )
          : null,
    );
  }

  Widget _buildMemberCard(EventTeamMember member, {bool highlight = false}) {
    final theme = Theme.of(context);
    final roleColor = _getRoleColor(member.role);
    final roleIcon = _getRoleIcon(member.role);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.darkCardDecoration.copyWith(
        border: highlight
            ? Border.all(color: roleColor.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(roleIcon, color: roleColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        member.role,
                        style: TextStyle(
                          fontSize: 11,
                          color: roleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (member.email != null || member.phone != null) ...[
                  const SizedBox(height: 8),
                  if (member.email != null)
                    Row(
                      children: [
                        Icon(
                          Ionicons.mail_outline,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            member.email!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (member.phone != null)
                    Row(
                      children: [
                        Icon(
                          Ionicons.call_outline,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.phone!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(Ionicons.ellipsis_vertical),
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => Future.delayed(
                  Duration.zero,
                  () => _showAddEditDialog(existingMember: member),
                ),
                child: const Row(
                  children: [
                    Icon(Ionicons.create_outline, size: 18),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => Future.delayed(Duration.zero, () => _deleteMember(member)),
                child: const Row(
                  children: [
                    Icon(Ionicons.trash_outline, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Remove', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
