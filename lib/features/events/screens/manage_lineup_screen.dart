import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';

import '../models/event_team_member.dart';
import '../services/event_team_service.dart';
import '../../../core/ui/bu_kit.dart';

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
  EventTeamService get _team => ref.read(eventTeamServiceProvider);
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
      final members = await _team.list(widget.eventId);

      setState(() {
        _teamMembers = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(couldNotLoad('team members', e))),
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
        await _team.add(eventId: widget.eventId, name: name, role: role, email: email, phone: phone);
      } else {
        // Update existing member
        await _team.update(existingMember.id, name: name, role: role, email: email, phone: phone);
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
          SnackBar(content: Text(couldNot('save team member', e))),
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
            style: FilledButton.styleFrom(backgroundColor: BuTokens.dark.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _team.remove(member.id);
        await _loadTeamMembers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team member removed successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(couldNot('remove team member', e))),
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
        return BuTokens.dark.soft;
      case TeamRole.coordinator:
        return BuTokens.dark.orangeSoft;
      case TeamRole.security:
        return BuTokens.dark.amber;
      case TeamRole.bartender:
        return BuTokens.dark.soft;
      case TeamRole.host:
        return BuTokens.dark.soft;
      case TeamRole.manager:
        return BuTokens.dark.soft;
      case TeamRole.photographer:
        return BuTokens.dark.amber;
      default:
        return BuTokens.dark.muted;
    }
  }

  List<EventTeamMember> _getMembersByRole(String role) {
    return _teamMembers.where((m) => m.role == role).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final djs = _getMembersByRole(TeamRole.dj);
    final otherMembers = _teamMembers.where((m) => m.role != TeamRole.dj).toList();

    Widget sectionTitle(String key, IconData icon, String title, {VoidCallback? onAdd, String? addTooltip}) => Row(
          children: [
            Icon(icon, color: bu.soft, size: 20),
            const SizedBox(width: BuSpace.s),
            Expanded(child: Text(title, key: Key(key), style: text.titleLarge)),
            if (onAdd != null) IconButton(onPressed: onAdd, icon: const Icon(Ionicons.add_outline, size: 20), tooltip: addTooltip),
          ],
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BuDetailAppBar(
        eyebrow: widget.eventName,
        title: 'Team & Lineup',
        actions: [IconButton(key: const Key('lineup-add'), onPressed: () => _showAddEditDialog(), icon: const Icon(Ionicons.add_circle_outline), tooltip: 'Add Team Member')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeamMembers,
              child: ListView(
                key: const Key('lineup-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, 88), // room for the Add button
                children: [
                  Text('${_teamMembers.length} team member${_teamMembers.length != 1 ? 's' : ''}', key: const Key('lineup-count'), style: text.bodyMedium?.copyWith(color: bu.muted)),
                  const SizedBox(height: BuSpace.l),
                  sectionTitle('lineup-djs-title', Ionicons.musical_notes_outline, 'DJs & Performers (${djs.length})', onAdd: () => _showAddEditDialog(), addTooltip: 'Add DJ/Performer'),
                  const SizedBox(height: BuSpace.m),
                  if (djs.isEmpty)
                    BuCard(
                      key: const Key('lineup-no-djs'),
                      child: Column(
                        children: [
                          Text('No DJs added yet', style: text.bodyMedium?.copyWith(color: bu.muted)),
                          const SizedBox(height: BuSpace.xs),
                          TextButton.icon(key: const Key('lineup-add-dj'), onPressed: () => _showAddEditDialog(), icon: const Icon(Ionicons.add_outline), label: const Text('Add DJ')),
                        ],
                      ),
                    )
                  else
                    for (final dj in djs) Padding(padding: const EdgeInsets.only(bottom: BuSpace.m), child: _buildMemberCard(dj, highlight: true)),
                  if (otherMembers.isNotEmpty) ...[
                    const SizedBox(height: BuSpace.xl),
                    sectionTitle('lineup-others-title', Ionicons.people_outline, 'Other Team Members (${otherMembers.length})'),
                    const SizedBox(height: BuSpace.m),
                    for (final member in otherMembers) Padding(padding: const EdgeInsets.only(bottom: BuSpace.m), child: _buildMemberCard(member)),
                  ],
                  if (_teamMembers.isEmpty) ...[
                    const SizedBox(height: BuSpace.xl),
                    BuCard(
                      key: const Key('lineup-empty'),
                      child: Column(
                        children: [
                          BuIconTile(icon: Ionicons.people_outline, size: 52),
                          const SizedBox(height: BuSpace.m),
                          Text('No team members yet', style: text.titleMedium),
                          const SizedBox(height: BuSpace.xs),
                          Text('Add the DJs, security and staff working this night.', style: text.bodySmall?.copyWith(color: bu.muted), textAlign: TextAlign.center),
                          const SizedBox(height: BuSpace.m),
                          FilledButton.icon(key: const Key('lineup-add-first'), onPressed: () => _showAddEditDialog(), icon: const Icon(Ionicons.add_outline), label: const Text('Add Team Member')),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: _teamMembers.isNotEmpty ? FloatingActionButton(key: const Key('lineup-fab'), onPressed: () => _showAddEditDialog(), child: const Icon(Ionicons.add_outline)) : null,
    );
  }

  Widget _buildMemberCard(EventTeamMember member, {bool highlight = false}) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final roleColor = _getRoleColor(member.role);
    final roleIcon = _getRoleIcon(member.role);

    Widget contact(IconData icon, String value, {bool ellipsis = false}) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(icon, size: 13, color: bu.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(value, style: text.bodySmall?.copyWith(color: bu.muted), overflow: ellipsis ? TextOverflow.ellipsis : null)),
            ],
          ),
        );

    return BuCard(
      key: Key('member-${member.id}'),
      accent: highlight ? roleColor : null,
      padding: const EdgeInsets.all(BuSpace.m + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(BuRadius.control)),
            child: Icon(roleIcon, color: roleColor, size: 22),
          ),
          const SizedBox(width: BuSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: text.titleMedium),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(BuRadius.pill)),
                  child: Text(member.role, style: text.labelSmall?.copyWith(color: roleColor, fontWeight: FontWeight.w700)),
                ),
                if (member.email != null) contact(Ionicons.mail_outline, member.email!, ellipsis: true),
                if (member.phone != null) contact(Ionicons.call_outline, member.phone!),
              ],
            ),
          ),
          PopupMenuButton(
            key: Key('member-menu-${member.id}'),
            icon: const Icon(Ionicons.ellipsis_vertical),
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('member-edit'),
                onTap: () => Future.delayed(Duration.zero, () => _showAddEditDialog(existingMember: member)),
                child: const Row(children: [Icon(Ionicons.create_outline, size: 18), SizedBox(width: 12), Text('Edit')]),
              ),
              PopupMenuItem(
                key: const Key('member-remove'),
                onTap: () => Future.delayed(Duration.zero, () => _deleteMember(member)),
                child: Row(children: [Icon(Ionicons.trash_outline, size: 18, color: bu.red), const SizedBox(width: 12), Text('Remove', style: TextStyle(color: bu.red))]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
