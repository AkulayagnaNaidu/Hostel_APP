import '../core/network/api_client.dart';
import '../core/storage/secure_storage_service.dart';
import '../services/auth_service.dart';
import '../services/beds_service.dart';
import '../services/bookings_service.dart';
import '../services/buildings_service.dart';
import '../services/complaints_service.dart';
import '../services/notifications_service.dart';
import '../services/payments_service.dart';
import '../services/tenant_portal_service.dart';

/// Global service locator — initialized in `main()` after dotenv load.
class AppServices {
  static late final SecureStorageService secureStorage;
  static late final ApiClient apiClient;
  static late final AuthService auth;
  static late final BuildingsService buildings;
  static late final BedsService beds;
  static late final BookingsService bookings;
  static late final PaymentsService payments;
  static late final ComplaintsService complaints;
  static late final TenantPortalService tenantPortal;
  static late final NotificationsService notifications;

  static Future<void> init() async {
    secureStorage = SecureStorageService();
    apiClient = ApiClient(secureStorage);
    auth = AuthService(apiClient, secureStorage);
    buildings = BuildingsService(apiClient);
    beds = BedsService(apiClient);
    bookings = BookingsService(apiClient);
    payments = PaymentsService(apiClient);
    complaints = ComplaintsService(apiClient);
    tenantPortal = TenantPortalService(apiClient);
    notifications = NotificationsService(apiClient);

    await auth.restoreSession();
  }
}
