import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/plain_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons/ionicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/services/supabase_auth_service.dart';
import '../../../core/ui/bu_kit.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _logoUrl;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentVendorUserProvider);
    _businessNameController = TextEditingController(text: user?.businessName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _logoUrl = user?.logoUrl;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (pickedFile == null) return;

      final currentUser = ref.read(currentVendorUserProvider);
      if (currentUser == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await pickedFile.readAsBytes();
      final fileExt = pickedFile.path.split('.').last.toLowerCase();
      final fileName = 'vendors/${currentUser.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage.from('media').uploadBinary(fileName, bytes, fileOptions: FileOptions(contentType: 'image/$fileExt'));

      final photoUrl = Supabase.instance.client.storage.from('media').getPublicUrl(fileName);

      setState(() {
        _logoUrl = photoUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(couldNot('upload photo', e)), backgroundColor: BuTokens.dark.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentVendorUserProvider);
      if (currentUser == null) {
        throw Exception('No user found');
      }

      // Update the vendor user with new data
      final updatedUser = currentUser.copyWith(businessName: _businessNameController.text.trim(), phone: _phoneController.text.trim(), logoUrl: _logoUrl, updatedAt: DateTime.now());

      // Call Supabase to update the profile
      await ref.read(supabaseAuthServiceProvider).updateVendorUser(updatedUser);

      // Refresh the auth state to get updated user data
      ref.invalidate(currentVendorUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated successfully'), backgroundColor: BuTokens.dark.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(couldNot('update profile', e)), backgroundColor: BuTokens.dark.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bu = context.bu;
    final text = Theme.of(context).textTheme;
    final shown = _businessNameController.text.trim();

    Widget field({
      required Key key,
      required TextEditingController controller,
      required String label,
      required IconData icon,
      String? Function(String?)? validator,
      TextInputType? keyboardType,
      bool enabled = true,
      Widget? suffix,
    }) => TextFormField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), suffixIcon: suffix),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const BuDetailAppBar(eyebrow: 'Account', title: 'Edit Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BuSpace.page, BuSpace.s, BuSpace.page, BuSpace.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The photo: the design's rounded tile with the business's initials, and a camera button to change it.
              Center(
                child: Stack(
                  children: [
                    Container(
                      key: const Key('profile-photo'),
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(BuRadius.hero),
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF392219), Color(0xFF211816)]),
                        border: Border.all(color: bu.orange.withValues(alpha: 0.5), width: 2),
                        image: _logoUrl != null ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover) : null,
                      ),
                      child:
                          _isUploadingPhoto
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : _logoUrl == null
                              ? Text(BuMiniVenue.initialsOf(shown.isEmpty ? '?' : shown), style: text.headlineMedium?.copyWith(color: bu.orangeSoft, fontWeight: FontWeight.w800))
                              : null,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Semantics(
                        button: true,
                        label: 'Change photo',
                        child: InkWell(
                          key: const Key('profile-photo-change'),
                          customBorder: const CircleBorder(),
                          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: bu.orange, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3)),
                            child: const Icon(Ionicons.camera, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BuSpace.xl),
              const BuEyebrow('Business'),
              const SizedBox(height: BuSpace.s),
              BuCard(
                child: Column(
                  children: [
                    field(
                      key: const Key('profile-business-name'),
                      controller: _businessNameController,
                      label: 'Business Name',
                      icon: Ionicons.storefront_outline,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your business name' : null,
                    ),
                    const SizedBox(height: BuSpace.m),
                    field(
                      key: const Key('profile-phone'),
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Ionicons.call_outline,
                      keyboardType: TextInputType.phone,
                      validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BuSpace.xl),
              const BuEyebrow('Sign-in'),
              const SizedBox(height: BuSpace.s),
              BuCard(
                child: field(
                  key: const Key('profile-email'),
                  controller: _emailController,
                  label: 'Email',
                  icon: Ionicons.mail_outline,
                  enabled: false,
                  suffix: Icon(Ionicons.lock_closed, size: 18, color: bu.muted),
                ),
              ),
              const SizedBox(height: BuSpace.s),
              Text('Your email is how you sign in, so it cannot be changed here.', style: text.bodySmall?.copyWith(color: bu.muted)),
              const SizedBox(height: BuSpace.xl),
              FilledButton(
                key: const Key('profile-save'),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
