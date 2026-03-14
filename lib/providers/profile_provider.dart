import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';
import 'auth_provider.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  final Ref _ref;

  ProfileNotifier(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() {
    final user = _ref.read(authProvider).user;
    state = AsyncValue.data(user);
  }

  Future<void> updateProfile({String? name, int? age, String? gender, double? height, bool? isPregnant, bool? isLactating}) async {
    try {
      final res = await apiClient.dio.put(ApiConstants.profile, data: {
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (height != null) 'height': height,
        if (isPregnant != null) 'is_pregnant': isPregnant,
        if (isLactating != null) 'is_lactating': isLactating,
      });
      final user = AppUser.fromJson(res.data);
      state = AsyncValue.data(user);
      _ref.read(authProvider.notifier).updateUser(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final res = await apiClient.dio.post(
      ApiConstants.profileAvatar,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final avatarUrl = res.data['avatar_url'] as String;
    final currentUser = state.value;
    if (currentUser != null) {
      final updated = currentUser.copyWith(avatarUrl: avatarUrl);
      state = AsyncValue.data(updated);
      _ref.read(authProvider.notifier).updateUser(updated);
    }
    return avatarUrl;
  }

  Future<bool> addChild({required String name, int? age, String? gender, String? allergies, double? height, String? email}) async {
    try {
      await apiClient.dio.post(ApiConstants.profileChild, data: {
        'name': name,
        'age': age,
        'gender': gender,
        'allergies': allergies,
        'height': height,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      // Refresh user from server
      final res = await apiClient.dio.get(ApiConstants.user);
      final user = AppUser.fromJson(res.data);
      state = AsyncValue.data(user);
      _ref.read(authProvider.notifier).updateUser(user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateChild({
    required String childId,
    String? name,
    int? age,
    String? gender,
    String? allergies,
    double? height,
    String? email,
  }) async {
    try {
      await apiClient.dio.put('${ApiConstants.profileChild}/$childId', data: {
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (gender != null) 'gender': gender,
        if (allergies != null) 'allergies': allergies,
        if (height != null) 'height': height,
        if (email != null) 'email': email,
      });
      final res = await apiClient.dio.get(ApiConstants.user);
      final user = AppUser.fromJson(res.data);
      state = AsyncValue.data(user);
      _ref.read(authProvider.notifier).updateUser(user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadChildAvatar(String childId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final res = await apiClient.dio.post(
      '${ApiConstants.profileChild}/$childId/avatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final avatarUrl = res.data['avatar_url'] as String;
    try {
      final res2 = await apiClient.dio.get(ApiConstants.user);
      final user = AppUser.fromJson(res2.data);
      state = AsyncValue.data(user);
      _ref.read(authProvider.notifier).updateUser(user);
    } catch (_) {
      // User refresh failed — avatar was uploaded, just refresh on next screen load
    }
    return avatarUrl;
  }

  Future<bool> deleteChild(String childId) async {
    try {
      await apiClient.dio.delete('${ApiConstants.profileChild}/$childId');
      final res = await apiClient.dio.get(ApiConstants.user);
      final user = AppUser.fromJson(res.data);
      state = AsyncValue.data(user);
      _ref.read(authProvider.notifier).updateUser(user);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<AppUser?>>((ref) {
  return ProfileNotifier(ref);
});
