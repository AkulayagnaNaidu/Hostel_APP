import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

class TenantPortalService {
  final ApiClient _client;

  TenantPortalService(this._client);

  Future<Map<String, dynamic>> fetchCompleteProfile() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.tenantCompleteProfile);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(XFile file) async {
    try {
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      });
      final resp = await _client.dio.post(
        ApiEndpoints.tenantUploadPhoto,
        data: formData,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<Map<String, dynamic>> postCommunityReport({
    required String title,
    required String type,
    required String details,
    required String location,
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.tenantCommunityReports,
        data: {
          'title': title,
          'type': type,
          'details': details,
          'location': location,
        },
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchCommunityReports() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.tenantCommunityReports);
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<Map<String, dynamic>> postSosAlert({
    required String type,
    required String message,
    required String location,
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.tenantSosAlerts,
        data: {'type': type, 'message': message, 'location': location},
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchWishlist() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.tenantWishlist);
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<void> addToWishlist({
    required String hostelId,
    required String hostelName,
  }) async {
    try {
      await _client.dio.post(
        ApiEndpoints.tenantWishlist,
        data: {'hostelId': hostelId, 'hostelName': hostelName},
      );
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<Map<String, dynamic>> fetchRewards() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.tenantRewardsMe);
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }
}
