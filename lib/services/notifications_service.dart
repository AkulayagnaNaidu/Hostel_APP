import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class NotificationsService {
  final ApiClient _client;

  NotificationsService(this._client);

  Future<List<Map<String, dynamic>>> fetchAll() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.notifications);
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client.dio.patch(ApiEndpoints.notificationRead(id));
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<void> markAllRead({String category = 'all'}) async {
    try {
      await _client.dio.post(
        ApiEndpoints.notificationsMarkAllRead,
        data: {'category': category},
      );
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }
}
