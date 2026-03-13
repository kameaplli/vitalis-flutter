import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../services/biometric_service.dart';
import '../providers/achievements_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/achievement_badges.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String? _gender;
  bool _editing = false;
  bool _isPregnant = false;
  bool _isLactating = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl.text = user?.name ?? '';
    _ageCtrl.text = user?.age?.toString() ?? '';
    _heightCtrl.text = user?.height?.toStringAsFixed(0) ?? '';
    _gender = user?.gender;
    _isPregnant = user?.isPregnant ?? false;
    _isLactating = user?.isLactating ?? false;
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isAvailable();
    final enabled = await SecureStorage.getBiometricsEnabled();
    if (mounted) setState(() { _biometricAvailable = available; _biometricEnabled = enabled; });
  }

  Future<void> _toggleBiometric(bool enable) async {
    // No password dialog here — the Profile screen has no access to the user's
    // password. Instead: set the enabled flag now; the next time the user logs
    // in with their password, auth_screen.dart will auto-save the credentials
    // and biometric login will become fully active from that point.
    try {
      if (enable) {
        await SecureStorage.setBiometricsEnabled(true);
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Biometric login enabled — sign out and back in once to activate it.'),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        await SecureStorage.clearBioCredentials();
        await SecureStorage.setBiometricsEnabled(false);
        await SecureStorage.setBiometricsPrompted(false);
        if (!mounted) return;
        setState(() => _biometricEnabled = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
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
                  Semantics(
                    label: 'Profile photo for ${user.name}',
                    image: avatarUrl != null,
                    child: CircleAvatar(
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
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Semantics(
                      button: true,
                      label: 'Change profile photo',
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: ExcludeSemantics(child: Icon(Icons.camera_alt, size: 18, color: Theme.of(context).colorScheme.onPrimary)),
                        ),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  prefixIcon: Icon(Icons.height),
                  suffixText: 'cm',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (_gender != 'male') ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.pregnant_woman),
                  title: const Text('Pregnant'),
                  subtitle: const Text('Adjusts your nutritional reference values'),
                  value: _isPregnant,
                  onChanged: (v) => setState(() => _isPregnant = v),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.child_friendly),
                  title: const Text('Lactating'),
                  subtitle: const Text('Adjusts your nutritional reference values'),
                  value: _isLactating,
                  onChanged: (v) => setState(() => _isLactating = v),
                ),
              ],
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
              if (user.height != null)
                ListTile(
                  leading: const Icon(Icons.height),
                  title: const Text('Height'),
                  trailing: Text('${user.height!.toStringAsFixed(0)} cm'),
                ),
              if (user.isPregnant)
                const ListTile(
                  leading: Icon(Icons.pregnant_woman),
                  title: Text('Pregnant'),
                  trailing: Text('Yes'),
                ),
              if (user.isLactating)
                const ListTile(
                  leading: Icon(Icons.child_friendly),
                  title: Text('Lactating'),
                  trailing: Text('Yes'),
                ),
            ],
            const ExcludeSemantics(child: Divider(height: 32)),
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
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notification preferences'),
              subtitle: const Text('Meals, hydration, supplements, eczema alerts'),
              trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
              onTap: () => GoRouter.of(context).push('/notifications'),
            ),
            _DarkModeToggle(),
            _ThemePicker(),
            const ExcludeSemantics(child: Divider(height: 32)),
            // Achievements section
            _AchievementsSection(),
            const ExcludeSemantics(child: Divider(height: 32)),
            // Sign out
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('You will need to sign in again to use Vitalis.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await ref.read(authProvider.notifier).logout();
                  if (mounted) context.go('/auth');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text('Permanently delete your account and all data'),
              onTap: () => _showDeleteAccountDialog(context),
            ),
            const ExcludeSemantics(child: Divider(height: 32)),
            // Children section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Family Members', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  tooltip: 'Add family member',
                  onPressed: () => _showAddChildDialog(context),
                ),
              ],
            ),
            if (user.profile.children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No family members added', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              )
            else
              ...user.profile.children.map((child) {
                final childAvatarUrl = child.avatarUrl != null
                    ? ApiConstants.resolveUrl(child.avatarUrl)
                    : null;
                return ListTile(
                  leading: Semantics(
                    label: 'Photo of ${child.name}',
                    image: childAvatarUrl != null,
                    child: CircleAvatar(
                      backgroundImage: childAvatarUrl != null
                          ? CachedNetworkImageProvider(childAvatarUrl) as ImageProvider
                          : null,
                      child: childAvatarUrl == null
                          ? Text(child.name[0].toUpperCase())
                          : null,
                    ),
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
                        tooltip: 'Edit ${child.name}',
                        onPressed: () => _showEditChildDialog(context, child),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error),
                        tooltip: 'Remove ${child.name}',
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

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all associated data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await apiClient.dio.delete(ApiConstants.deleteAccount);
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/auth');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
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
      height: double.tryParse(_heightCtrl.text),
      isPregnant: _isPregnant,
      isLactating: _isLactating,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
  }

  void _showAddChildDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final allergiesCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
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
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (for reminders)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
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
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
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
    final emailCtrl = TextEditingController(text: child.email ?? '');
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
                          ? Icon(Icons.check_circle, size: 32, color: Theme.of(context).colorScheme.primary)
                          : (child.avatarUrl == null
                              ? Text(child.name[0].toUpperCase(), style: const TextStyle(fontSize: 28))
                              : null),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                      child: Icon(Icons.camera_alt, size: 14, color: Theme.of(context).colorScheme.onPrimary),
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
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (for reminders)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
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
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
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

class _DarkModeToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    return SwitchListTile(
      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
      title: const Text('Dark mode'),
      subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active'),
      value: isDark,
      onChanged: (_) => ref.read(darkModeProvider.notifier).toggle(),
    );
  }
}

class _ThemePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);
    return ListTile(
      leading: Icon(current.icon),
      title: const Text('App theme'),
      subtitle: Text(current.label),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Choose Theme',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ...AppSkin.values.map((skin) => RadioListTile<AppSkin>(
                      value: skin,
                      groupValue: current,
                      title: Text(skin.label),
                      secondary: Icon(skin.icon),
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(themeProvider.notifier).setSkin(v);
                        }
                        Navigator.pop(ctx);
                      },
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AchievementsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(achievementsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load achievements', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          data: (data) => AchievementBadgesWidget(
            badges: data.badges,
            stats: data.stats,
          ),
        ),
      ],
    );
  }
}
