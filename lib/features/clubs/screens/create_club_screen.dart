import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:responsive_builder/responsive_builder.dart';

import '../../../shared/models/club.dart';
import '../../../shared/services/club_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_wrapper.dart';
import '../../../core/utils/responsive_utils.dart' as utils;

class CreateClubScreen extends ConsumerStatefulWidget {
  const CreateClubScreen({super.key});

  @override
  ConsumerState<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends ConsumerState<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _dressCodeController = TextEditingController();
  final _ageRequirementController = TextEditingController();
  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();

  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _dressCodeController.dispose();
    _ageRequirementController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final clubService = ClubService();
      final categories = await clubService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final clubService = ClubService();
      
      final request = CreateClubRequest(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        priceMin: _priceMinController.text.isNotEmpty 
            ? double.tryParse(_priceMinController.text) 
            : null,
        priceMax: _priceMaxController.text.isNotEmpty 
            ? double.tryParse(_priceMaxController.text) 
            : null,
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        websiteUrl: _websiteController.text.trim().isEmpty 
            ? null 
            : _websiteController.text.trim(),
        categoryId: _selectedCategoryId,
        dressCode: _dressCodeController.text.trim().isEmpty 
            ? null 
            : _dressCodeController.text.trim(),
        ageRequirement: _ageRequirementController.text.trim().isEmpty 
            ? null 
            : _ageRequirementController.text.trim(),
      );

      await clubService.createClub(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club created successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create club: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: ResponsiveText.titleLarge('Create Club'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveWrapper(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(utils.ResponsiveUtils.getResponsivePadding(context)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      ResponsiveContainer(
                        decoration: AppTheme.darkContainerDecoration,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Ionicons.add_circle_outline,
                                  color: theme.colorScheme.primary,
                                  size: utils.ResponsiveUtils.getResponsiveIconSize(context),
                                ),
                                SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.75),
                                Expanded(
                                  child: ResponsiveText.headlineSmall(
                                    'Add New Club',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.75),
                            ResponsiveText.bodyLarge(
                              'Fill in the details below to create a new club',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                      // Basic Information Section
                      _buildSectionHeader(context, 'Basic Information', Ionicons.information_circle_outline),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                      ResponsiveContainer(
                        decoration: AppTheme.darkCardDecoration,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'Club Name *',
                              hint: 'Enter club name',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Club name is required';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            _buildTextField(
                              controller: _locationController,
                              label: 'Location *',
                              hint: 'Enter club location',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Location is required';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            _buildTextField(
                              controller: _descriptionController,
                              label: 'Description',
                              hint: 'Enter club description',
                              maxLines: 3,
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            _buildDropdownField(
                              label: 'Category',
                              value: _selectedCategoryId,
                              items: _categories.map((category) {
                                return DropdownMenuItem<String>(
                                  value: category['id'],
                                  child: Text(category['name']),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategoryId = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                      // Contact Information Section
                      _buildSectionHeader(context, 'Contact Information', Ionicons.call_outline),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                      ResponsiveContainer(
                        decoration: AppTheme.darkCardDecoration,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              hint: '+1 (555) 123-4567',
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'contact@club.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            _buildTextField(
                              controller: _websiteController,
                              label: 'Website',
                              hint: 'https://www.club.com',
                              keyboardType: TextInputType.url,
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                      // Pricing Section
                      _buildSectionHeader(context, 'Pricing', Ionicons.cash_outline),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                      ResponsiveContainer(
                        decoration: AppTheme.darkCardDecoration,
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _priceMinController,
                                label: 'Min Price',
                                hint: '0.00',
                                keyboardType: TextInputType.number,
                                prefix: '\$',
                              ),
                            ),
                            SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            Expanded(
                              child: _buildTextField(
                                controller: _priceMaxController,
                                label: 'Max Price',
                                hint: '100.00',
                                keyboardType: TextInputType.number,
                                prefix: '\$',
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),

                      // Policies Section
                      _buildSectionHeader(context, 'Policies', Ionicons.shield_checkmark_outline),
                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),

                      ResponsiveContainer(
                        decoration: AppTheme.darkCardDecoration,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _dressCodeController,
                              label: 'Dress Code',
                              hint: 'Smart casual to formal attire required',
                            ),
                            SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context)),
                            _buildTextField(
                              controller: _ageRequirementController,
                              label: 'Age Requirement',
                              hint: '21+ with valid ID',
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 3),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _createClub,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create Club'),
                        ),
                      ),

                      SizedBox(height: utils.ResponsiveUtils.getResponsiveSpacing(context) * 2),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        SizedBox(width: utils.ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
        ResponsiveText.titleMedium(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
} 