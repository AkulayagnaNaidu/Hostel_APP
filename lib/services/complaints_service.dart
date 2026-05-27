import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class ComplaintsService {
  final ApiClient _client;

  ComplaintsService(this._client);

  Future<Map<String, dynamic>> createComplaint({
    required String title,
    required String description,
    required String category,
    required String priority,
    String? buildingId,
    String? tenantId,
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.complaints,
        data: {
          'title': title,
          'description': description,
          'category': category,
          'priority': priority,
          if (buildingId != null) 'buildingId': buildingId,
          if (tenantId != null) 'tenantId': tenantId,
        },
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyComplaints() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.complaintsMe);
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }
}
