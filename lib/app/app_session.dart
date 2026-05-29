import 'app_services.dart';
import 'app_state.dart';
import '../models/auth_user.dart';

/// Keeps UI session state in sync with [AuthService] and secure storage.
class AppSession {
  AppSession._();

  static Future<void> hydrateFromStorage() async {
    if (!AppServices.auth.isLoggedIn.value) {
      clearLocalProfile();
      return;
    }

    final storage = AppServices.secureStorage;
    final name = await storage.readUserName();
    final email = await storage.readUserEmail();
    final phone = await storage.readUserPhone();

    if (name != null && name.isNotEmpty) {
      savedNameNotifier.value = name;
    } else if (AppServices.auth.currentUser?.name != null) {
      savedNameNotifier.value = AppServices.auth.currentUser!.name;
    } else {
      savedNameNotifier.value = 'Resident';
    }

    if (email != null) savedEmailNotifier.value = email;
    if (phone != null) savedPhoneNotifier.value = phone;

    try {
      final profile = await AppServices.tenantPortal.fetchCompleteProfile();
      _applyProfileMap(profile);
    } catch (_) {
      // Offline or profile incomplete — keep stored values.
    }
  }

  static Future<void> applyAuthUser(
    AuthUser user, {
    required String email,
    String? phone,
  }) async {
    final name = user.name ?? email.split('@').first;
    savedNameNotifier.value = name;
    savedEmailNotifier.value = email;
    if (phone != null && phone.isNotEmpty) {
      savedPhoneNotifier.value = phone;
    }
    await AppServices.secureStorage.saveUserProfile(
      name: name,
      email: email,
      phone: phone,
    );
  }

  static Future<void> logout() async {
    await AppServices.auth.logout();
    clearLocalProfile();
  }

  static void clearLocalProfile() {
    savedNameNotifier.value = null;
    savedEmailNotifier.value = null;
    savedPhoneNotifier.value = null;
    profileImageNotifier.value = null;
  }

  static void _applyProfileMap(Map<String, dynamic> profile) {
    final user = profile['user'] as Map<String, dynamic>? ?? profile;
    final name = user['name']?.toString();
    final email = user['email']?.toString();
    final phone = user['phone']?.toString();

    if (name != null && name.isNotEmpty) savedNameNotifier.value = name;
    if (email != null && email.isNotEmpty) savedEmailNotifier.value = email;
    if (phone != null && phone.isNotEmpty) savedPhoneNotifier.value = phone;

    final emergency = profile['emergencyContact'] as Map<String, dynamic>?;
    if (emergency != null) {
      final eName = emergency['name']?.toString();
      final ePhone = emergency['phone']?.toString();
      if (eName != null && eName.isNotEmpty) {
        savedEmergencyNameNotifier.value = eName;
      }
      if (ePhone != null && ePhone.isNotEmpty) {
        savedEmergencyPhoneNotifier.value = ePhone;
      }
    }
  }
}
