import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';

/// Provider managing viewer profiles, profile creation, switching, and settings.
class ProfileProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<UserProfile> _profiles = [];
  UserProfile _activeProfile = UserProfile.createDefault();
  bool _isLoading = false;

  void Function(UserProfile activeProfile)? onProfileChanged;

  List<UserProfile> get profiles => List.unmodifiable(_profiles);
  UserProfile get activeProfile => _activeProfile;
  bool get isLoading => _isLoading;
  bool get isKidsActive => _activeProfile.isKids;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profiles = await _storageService.getProfiles();
      final activeId = await _storageService.getActiveProfileId();
      _activeProfile = _profiles.firstWhere(
        (p) => p.id == activeId,
        orElse: () => _profiles.isNotEmpty
            ? _profiles.first
            : UserProfile.createDefault(),
      );
    } catch (e) {
      debugPrint('[ProfileProvider] Error initializing profiles: $e');
      if (_profiles.isEmpty) {
        final def = UserProfile.createDefault();
        _profiles = [def];
        _activeProfile = def;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchProfile(String profileId) async {
    if (_activeProfile.id == profileId) return;

    final target = _profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => _activeProfile,
    );
    if (target.id == _activeProfile.id) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedTarget = target.copyWith(lastActiveAt: now);

    final updatedProfiles = _profiles.map((p) {
      return p.id == target.id ? updatedTarget : p;
    }).toList();

    _profiles = updatedProfiles;
    _activeProfile = updatedTarget;
    notifyListeners();

    await _storageService.setActiveProfileId(target.id);
    await _storageService.saveProfiles(_profiles);

    onProfileChanged?.call(_activeProfile);
  }

  Future<UserProfile> createProfile({
    required String name,
    required String avatarIcon,
    int avatarColorIndex = 0,
    bool isKids = false,
    String? pin,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'profile_$now';

    final newProfile = UserProfile(
      id: id,
      name: name.trim().isNotEmpty ? name.trim() : 'Viewer',
      avatarIcon: avatarIcon,
      avatarColorIndex: avatarColorIndex,
      isKids: isKids,
      pin: pin != null && pin.length == 4 ? pin : null,
      createdAt: now,
      lastActiveAt: now,
    );

    _profiles = [..._profiles, newProfile];
    notifyListeners();

    await _storageService.saveProfiles(_profiles);
    return newProfile;
  }

  Future<void> updateProfile(UserProfile updated) async {
    final index = _profiles.indexWhere((p) => p.id == updated.id);
    if (index < 0) return;

    final list = List<UserProfile>.from(_profiles);
    list[index] = updated;
    _profiles = list;

    if (_activeProfile.id == updated.id) {
      _activeProfile = updated;
    }
    notifyListeners();

    await _storageService.saveProfiles(_profiles);
    if (_activeProfile.id == updated.id) {
      onProfileChanged?.call(_activeProfile);
    }
  }

  Future<bool> deleteProfile(String profileId) async {
    if (_profiles.length <= 1) return false;

    final list = _profiles.where((p) => p.id != profileId).toList();
    if (list.isEmpty) return false;

    _profiles = list;

    if (_activeProfile.id == profileId) {
      _activeProfile = list.first;
      await _storageService.setActiveProfileId(_activeProfile.id);
      onProfileChanged?.call(_activeProfile);
    }

    notifyListeners();
    await _storageService.saveProfiles(_profiles);
    return true;
  }
}
