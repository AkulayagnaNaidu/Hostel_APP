import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class BookingsService {
  final ApiClient _client;

  BookingsService(this._client);

  Future<Map<String, dynamic>> createBooking({
    String? tenantId,
    required String buildingId,
    required String category,
    required String moveInDate,
    required num totalAmount,
    required num securityDeposit,
    required num onboardingFee,
    required String method,
    required String guestName,
    required String email,
    required String phone,
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.bookings,
        data: {
          if (tenantId != null) 'tenantId': tenantId,
          'buildingId': buildingId,
          'category': category,
          'moveInDate': moveInDate,
          'totalAmount': totalAmount,
          'securityDeposit': securityDeposit,
          'onboardingFee': onboardingFee,
          'method': method,
          'guestName': guestName,
          'email': email,
          'phone': phone,
        },
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyBookings() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.bookingsMe);
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }
}
