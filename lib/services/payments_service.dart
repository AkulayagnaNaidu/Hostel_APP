import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class PaymentsService {
  final ApiClient _client;

  PaymentsService(this._client);

  Future<List<Map<String, dynamic>>> fetchMyPayments() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.paymentsMe);
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<Map<String, dynamic>> createPayment({
    required String tenantId,
    required String buildingId,
    required num amount,
    required String type,
    required String method,
    required String month,
    String status = 'Paid',
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.payments,
        data: {
          'tenantId': tenantId,
          'buildingId': buildingId,
          'amount': amount,
          'type': type,
          'method': method,
          'month': month,
          'status': status,
        },
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }
}
