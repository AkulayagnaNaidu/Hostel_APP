/// Safe parsing helpers for inconsistent API response shapes.
class ResponseParser {
  ResponseParser._();

  /// Extracts a list from raw Dio response data.
  /// Handles bare lists or common wrappers: `{ data: [...] }`, `{ items: [...] }`.
  static List<Map<String, dynamic>> asMapList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (data is Map) {
      for (final key in ['data', 'items', 'results', 'buildings', 'notifications']) {
        final nested = data[key];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      }
    }
    return const [];
  }

  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }
}
