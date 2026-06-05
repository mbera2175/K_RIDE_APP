import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

// ── Model ────────────────────────────────────────────────────
class MapplsPlaceSuggestion {
  final String eLoc;       // unique place id (e.g. "MMI000")
  final String placeName;
  final String placeAddress;
  final double? latitude;
  final double? longitude;

  const MapplsPlaceSuggestion({
    required this.eLoc,
    required this.placeName,
    required this.placeAddress,
    this.latitude,
    this.longitude,
  });

  /// Display label shown in the dropdown row
  String get displayName => placeName;
  String get displaySub  => placeAddress;

  @override
  String toString() => '$placeName, $placeAddress';
}

// ── Service ──────────────────────────────────────────────────
class MapplsPlaceService {
  /// Fetch autocomplete recommendations using backend proxy
  static Future<List<MapplsPlaceSuggestion>> autocomplete(
    String query, {
    double? nearLat,
    double? nearLng,
    int maxResults = 5,
  }) async {
    if (query.trim().length < 2) return [];

    final token = AuthService.token;
    if (token.isEmpty) return [];

    try {
      final queryParams = <String, String>{
        'query': query.trim(),
      };
      if (nearLat != null && nearLng != null) {
        queryParams['lat'] = '$nearLat';
        queryParams['lng'] = '$nearLng';
      }

      final uri = Uri.parse('${AppConstants.baseUrl}/api/map/autocomplete')
          .replace(queryParameters: queryParams);

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final raw = body['suggestedLocations'] as List? ??
          body['suggestedSearches'] as List? ??
          [];

      final List<MapplsPlaceSuggestion> suggestions = [];
      for (final item in raw.take(maxResults)) {
        final lat = (item['latitude'] as num?)?.toDouble() ??
                    (item['lat'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble() ??
                    (item['lng'] as num?)?.toDouble();
        suggestions.add(MapplsPlaceSuggestion(
          eLoc: item['eLoc']?.toString() ?? '',
          placeName: item['placeName']?.toString() ??
              item['description']?.toString() ?? query,
          placeAddress: item['placeAddress']?.toString() ??
              item['detailedAddress']?.toString() ?? '',
          latitude: lat,
          longitude: lng,
        ));
      }
      return suggestions;
    } catch (e) {
      debugPrint('Proxy autocomplete error: $e');
      return [];
    }
  }

  /// Resolves coordinates for a place using its eLoc via backend proxy
  static Future<MapplsPlaceSuggestion?> placeDetail(String eLoc) async {
    if (eLoc.isEmpty) return null;

    final token = AuthService.token;
    if (token.isEmpty) return null;

    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/api/map/place-detail')
          .replace(queryParameters: {'eLoc': eLoc});

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      final results = body['copResults'] as Map<String, dynamic>?;
      if (results == null) return null;

      final lat = (results['latitude'] as num?)?.toDouble();
      final lng = (results['longitude'] as num?)?.toDouble();

      return MapplsPlaceSuggestion(
        eLoc: eLoc,
        placeName: results['formattedAddress']?.toString() ?? eLoc,
        placeAddress: results['city']?.toString() ?? '',
        latitude: lat,
        longitude: lng,
      );
    } catch (e) {
      debugPrint('Proxy place detail error: $e');
      return null;
    }
  }

  /// Reverse geocodes coordinates to a readable address using backend proxy
  static Future<String?> reverseGeocode(double lat, double lng) async {
    final token = AuthService.token;
    if (token.isEmpty) return null;

    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/api/map/reverse-geocode')
          .replace(queryParameters: {
        'lat': '$lat',
        'lng': '$lng',
      });

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      final results = body['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        return first['formatted_address']?.toString() ??
            first['formattedAddress']?.toString();
      }
    } catch (e) {
      debugPrint('Proxy reverse geocode error: $e');
    }
    return null;
  }
}
