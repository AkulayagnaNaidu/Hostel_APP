/// REST paths for Livora Hostel Hub (base URL from [EnvConfig]).
class ApiEndpoints {
  // Auth
  static const authLogin = '/api/auth/login';
  static const authRegister = '/api/auth/register';

  // Buildings — public
  static const buildingsPublic = '/api/buildings/public';
  static String buildingPublic(String id) => '/api/buildings/public/$id';
  static const buildingsPublicStats = '/api/buildings/public/stats';

  // Buildings — owner
  static const buildings = '/api/buildings';

  // Floors, rooms, beds
  static String floorsByBuilding(String buildingId) =>
      '/api/floors/building/$buildingId';
  static String roomsByFloor(String floorId) => '/api/rooms/$floorId';
  static const beds = '/api/beds';

  // Bookings
  static const bookings = '/api/bookings';
  static const bookingsMe = '/api/bookings/me';

  // Payments
  static const payments = '/api/payments';
  static const paymentsMe = '/api/payments/me';

  // Complaints
  static const complaints = '/api/complaints';
  static const complaintsMe = '/api/complaints/me';

  // Tenant portal
  static const tenantCompleteProfile = '/api/tenant-portal/complete-profile';
  static const tenantUploadPhoto = '/api/tenant-portal/upload-photo';
  static const tenantCommunityReports = '/api/tenant-portal/community-reports';
  static const tenantSosAlerts = '/api/tenant-portal/sos-alerts';
  static const tenantWishlist = '/api/tenant-portal/wishlist';
  static const tenantRewardsMe = '/api/tenant-portal/rewards/me';

  // Notifications
  static const notifications = '/api/notifications';
  static String notificationRead(String id) => '/api/notifications/$id/read';
  static const notificationsMarkAllRead = '/api/notifications/mark-all-read';
}
