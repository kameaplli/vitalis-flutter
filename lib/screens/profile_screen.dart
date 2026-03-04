import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../services/biometric_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _gender;
  bool _editing = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl.text = user?.name ?? '';
    _ageCtrl.text = user?.age?.toString() ?? '';
    _gender = user?.gender;
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isAvailable();
    final enabled = await SecureStorage.getBiometricsEnabled();
    if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      // Re-run the full offer flow: authenticate then store credentials
      final ok = await BiometricService.authenticate(reason: 'Confirm to enable biometric login');
      if (!ok || !mounted) return;
      // We don't have the password here — ask user to re-enter it
      final password = await _askPassword();
      if (password == null || !mounted) return;
      final user = ref.read(authProvider).user;
      await SecureStorage.saveBioCredentials(
        email: user?.email ?? '',
        password: password,
        name: user?.name ?? '',
      );
      await SecureStorage.setBiometricsEnabled(true);
      await SecureStorage.setBiometricsPrompted(true);
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login enabled ✓')),
      );
    } else {
      await SecureStorage.clearBioCredentials();
      if (mounted) setState(() => _biometricEnabled = false);
    }
  }

  Future<String?> _askPassword() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Your password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Confirm')),
        ],
      ),
    ).then((result) {
      ctrl.dispose();
      return (result?.isEmpty == true) ? null : result;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final avatarUrl = user.avatarUrl != null
        ? ApiConstants.resolveUrl(user.avatarUrl)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: () {
              if (_editing) _saveProfile();
              setState(() => _editing = !_editing);
            },
            child: Text(_editing ? 'Save' : 'Edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'V',
                            style: const TextStyle(fontSize: 40),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Profile fields
            if (_editing) ...[
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageCtrl,
                decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake_outlined)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Name'),
                trailing: Text(user.name),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                trailing: Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              ),
              if (user.age != null)
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Age'),
                  trailing: Text('${user.age}'),
                ),
              if (user.gender != null)
                ListTile(
                  leading: const Icon(Icons.wc),
                  title: const Text('Gender'),
                  trailing: Text(user.gender!),
                ),
            ],
            const Divider(height: 32),
            // Biometric login toggle
            if (_biometricAvailable)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometric login'),
                subtitle: Text(_biometricEnabled
                    ? 'Fingerprint / Face ID active'
                    : 'Use fingerprint or face to sign in'),
                value: _biometricEnabled,
                onChanged: _toggleBiometric,
              ),
            const Divider(height: 32),
            // Children section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Family Members', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: () => _showAddChildDialog(context),
                ),
              ],
            ),
            if (user.profile.children.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No family members added', style: TextStyle(color: Colors.grey)),
              )
            else
              ...user.profile.children.map((child) {
                final childAvatarUrl = child.avatarUrl != null
                    ? ApiConstants.resolveUrl(child.avatarUrl)
                    : null;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: childAvatarUrl != null
                        ? CachedNetworkImageProvider(childAvatarUrl) as ImageProvider
                        : null,
                    child: childAvatarUrl == null
                        ? Text(child.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(child.name),
                  subtitle: Text([
                    if (child.age != null) '${child.age} yr',
                    if (child.gender != null) child.gender!,
                    if (child.height != null) '${child.height!.toStringAsFixed(0)} cm',
                  ].join(' • ')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditChildDialog(context, child),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _deleteChild(child.id),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: img.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          minimumAspectRatio: 1.0,
        ),
      ],
    );
    if (cropped == null) return;
    final notifier = ref.read(profileProvider.notifier);
    try {
      await notifier.uploadAvatar(cropped.path);
    } catch (e) {
      if (mounted) {
        final msg = e is DioException
            ? (e.response?.data?['detail'] ?? e.message ?? e.toString())
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $msg'), duration: const Duration(seconds: 6)));
      }
    }
  }

  Future<void> _saveProfile() async {
    await ref.read(profileProvider.notifier).updateProfile(
      name: _nameCtrl.text.trim(),
      age: int.tryParse(_ageCtrl.text),
      gender: _gender,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
  }

  void _showAddChildDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final allergiesCtrl = TextEditingController();
    String? gender;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Family Member'),
        content: SingleChildScrollView(
          child: StatefulBuilder(builder: (ctx, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              TextField(controller: ageCtrl, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(
                controller: heightCtrl,
                decoration: const InputDecoration(labelText: 'Height (cm)', suffixText: 'cm'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => ss(() => gender = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: allergiesCtrl, decoration: const InputDecoration(labelText: 'Allergies (optional)')),
            ],
          )),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(profileProvider.notifier).addChild(
                name: nameCtrl.text.trim(),
                age: int.tryParse(ageCtrl.text),
                gender: gender,
                allergies: allergiesCtrl.text.trim().isEmpty ? null : allergiesCtrl.text.trim(),
                height: double.tryParse(heightCtrl.text),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditChildDialog(BuildContext context, dynamic child) {
    final nameCtrl = TextEditingController(text: child.name);
    final ageCtrl = TextEditingController(text: child.age?.toString() ?? '');
    final heightCtrl = TextEditingController(text: child.height?.toStringAsFixed(0) ?? '');
    final allergiesCtrl = TextEditingController(text: child.allergies ?? '');
    String? gender = child.gender;
    String? pendingImagePath;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Family Member'),
        content: SingleChildScrollView(
          child: StatefulBuilder(builder: (ctx, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar picker
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final img = await picker.pickImage(source: ImageSource.gallery);
                  if (img == null) return;
                  final cropped = await ImageCropper().cropImage(
                    sourcePath: img.path,
                    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                    uiSettings: [
                      AndroidUiSettings(
                        toolbarTitle: 'Crop Photo',
                        lockAspectRatio: true,
                        initAspectRatio: CropAspectRatioPreset.square,
                        hideBottomControls: false,
                      ),
                      IOSUiSettings(
                        title: 'Crop Photo',
                        aspectRatioLockEnabled: true,
                        minimumAspectRatio: 1.0,
                      ),
                    ],
                  );
                  if (cropped != null) ss(() => pendingImagePath = cropped.path);
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: pendingImagePath != null
                          ? null
                          : (child.avatarUrl != null
                              ? CachedNetworkImageProvider(ApiConstants.resolveUrl(child.avatarUrl)) as ImageProvider
                              : null),
                      child: pendingImagePath != null
                          ? const Icon(Icons.check_circle, size: 32, color: Colors.green)
                          : (child.avatarUrl == null
                              ? Text(child.name[0].toUpperCase(), style: const TextStyle(fontSize: 28))
                              : null),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              TextField(controller: ageCtrl, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(
                controller: heightCtrl,
                decoration: const InputDecoration(labelText: 'Height (cm)', suffixText: 'cm'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => ss(() => gender = v),
              ),
              const SizedBox(height: 8),
              TextField(controller: allergiesCtrl, decoration: const InputDecoration(labelText: 'Allergies (optional)')),
            ],
          )),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final notifier = ref.read(profileProvider.notifier);
              if (pendingImagePath != null) {
                try {
                  await notifier.uploadChildAvatar(child.id, pendingImagePath!);
                } catch (e) {
                  if (mounted) {
                    final msg = e is DioException
                        ? (e.response?.data?['detail'] ?? e.message ?? e.toString())
                        : e.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Photo upload failed: $msg'), duration: const Duration(seconds: 6)));
                  }
                }
              }
              await notifier.updateChild(
                childId: child.id,
                name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                age: int.tryParse(ageCtrl.text),
                gender: gender,
                allergies: allergiesCtrl.text.trim().isEmpty ? null : allergiesCtrl.text.trim(),
                height: double.tryParse(heightCtrl.text),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChild(String childId) async {
    final ok = await ref.read(profileProvider.notifier).deleteChild(childId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove family member')));
    }
  }
}
