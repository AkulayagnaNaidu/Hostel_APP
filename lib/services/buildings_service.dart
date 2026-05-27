import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/property.dart';

class PlatformStats {
  final int tenants;
  final int properties;
  final int cities;
  final String rating;

  PlatformStats({
    required this.tenants,
    required this.properties,
    required this.cities,
    required this.rating,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) {
    return PlatformStats(
      tenants: _asInt(json['tenants']),
      properties: _asInt(json['properties']),
      cities: _asInt(json['cities']),
      rating: json['rating']?.toString() ?? '4.8/5',
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

class BuildingsService {
  final ApiClient _client;

  BuildingsService(this._client);

  Future<List<Property>> fetchPublicBuildings() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.buildingsPublic);
      final list = resp.data as List<dynamic>;
      return list
          .map((e) => Property.fromBuildingJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<Property> fetchPublicBuilding(String id) async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.buildingPublic(id));
      return Property.fromBuildingJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<PlatformStats> fetchPublicStats() async {
    try {
      final resp = await _client.dio.get(ApiEndpoints.buildingsPublicStats);
      return PlatformStats.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchOwnerBuildings({
    bool lightweight = true,
  }) async {
    try {
      final resp = await _client.dio.get(
        ApiEndpoints.buildings,
        queryParameters: {'lightweight': lightweight.toString()},
      );
      return (resp.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }
}
