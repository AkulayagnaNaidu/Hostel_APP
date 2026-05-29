import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

/// Resolved bed for booking API ([sharingType] + [bedNumber]).
class BedSelection {
  final String sharingType;
  final String bedNumber;
  final String? bedId;

  const BedSelection({
    required this.sharingType,
    required this.bedNumber,
    this.bedId,
  });
}

class BedsService {
  final ApiClient _client;

  BedsService(this._client);

  /// Maps UI room labels to API sharing types.
  static String sharingTypeFromRoomLabel(String roomLabel) {
    final normalized = roomLabel.toLowerCase();
    if (normalized.contains('single')) return 'Single';
    if (normalized.contains('3') || normalized.contains('triple')) {
      return 'Triple';
    }
    if (normalized.contains('double') || normalized.contains('2')) {
      return 'Double';
    }
    return 'Double';
  }

  /// Finds first vacant bed matching [sharingType] for a building.
  Future<BedSelection?> findAvailableBed({
    required String buildingId,
    required String sharingType,
  }) async {
    try {
      final floorsResp = await _client.dio.get(
        ApiEndpoints.floorsByBuilding(buildingId),
      );
      final floors = floorsResp.data as List<dynamic>? ?? [];
      for (final floor in floors) {
        final floorMap = floor as Map<String, dynamic>;
        final floorId = floorMap['_id']?.toString();
        if (floorId == null) continue;

        final roomsResp = await _client.dio.get(ApiEndpoints.roomsByFloor(floorId));
        final rooms = roomsResp.data as List<dynamic>? ?? [];
        for (final room in rooms) {
          final roomMap = room as Map<String, dynamic>;
          final roomSharing = roomMap['sharingType']?.toString();
          if (roomSharing != null &&
              !_sharingMatches(roomSharing, sharingType)) {
            continue;
          }

          final beds = roomMap['beds'];
          if (beds is List) {
            for (final bed in beds) {
              final bedMap = bed as Map<String, dynamic>;
              if (_isBedAvailable(bedMap)) {
                return BedSelection(
                  sharingType: sharingType,
                  bedNumber: bedMap['bedNumber']?.toString() ??
                      bedMap['number']?.toString() ??
                      '1',
                  bedId: bedMap['_id']?.toString(),
                );
              }
            }
          }
        }
      }

      final bedsResp = await _client.dio.get(
        ApiEndpoints.beds,
        queryParameters: {'buildingId': buildingId, 'status': 'vacant'},
      );
      final bedsList = bedsResp.data as List<dynamic>? ?? [];
      for (final bed in bedsList) {
        final bedMap = bed as Map<String, dynamic>;
        final bedSharing = bedMap['sharingType']?.toString();
        if (bedSharing != null && !_sharingMatches(bedSharing, sharingType)) {
          continue;
        }
        if (_isBedAvailable(bedMap)) {
          return BedSelection(
            sharingType: sharingType,
            bedNumber: bedMap['bedNumber']?.toString() ??
                bedMap['number']?.toString() ??
                '1',
            bedId: bedMap['_id']?.toString(),
          );
        }
      }
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
    return null;
  }

  static bool _sharingMatches(String a, String b) {
    return a.toLowerCase() == b.toLowerCase();
  }

  static bool _isBedAvailable(Map<String, dynamic> bed) {
    final status = bed['status']?.toString().toLowerCase();
    if (status == null) return true;
    return status == 'vacant' ||
        status == 'available' ||
        status == 'empty' ||
        status == 'free';
  }

  static BedSelection fallback(String sharingType) {
    return BedSelection(
      sharingType: sharingType,
      bedNumber: '1',
    );
  }
}
