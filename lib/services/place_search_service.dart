// lib/services/mappls_place_service.dart
//
// Mappls Place Autocomplete + Place Detail service.
// Uses OAuth2 token from your existing client_id / client_secret.
//
// Usage:
//   final results = await MapplsPlaceService.autocomplete('Connaught');
//   final detail  = await MapplsPlaceService.placeDetail(results.first.eLoc);

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

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
  // ── Credentials (same as AndroidManifest / main.dart) ────
  static const _clientId = AppConstants.mapplsAtlasClientId;
  static const _clientSecret = AppConstants.mapplsAtlasClientSecret;

  // ── Token cache ──────────────────────────────────────────
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Fetch (or return cached) OAuth2 access token
  static Future<String?> _getToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      final res = await http.post(
        Uri.parse('https://outpost.mappls.com/api/security/oauth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': _clientId,
          'client_secret': _clientSecret,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _accessToken = data['access_token'] as String?;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        // Expire 60 s early to be safe
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: expiresIn - 60));
        return _accessToken;
      }
    } catch (e) {
      debugPrint('Mappls token error: $e');
    }
    return null;
  }

  // ── Autocomplete ─────────────────────────────────────────
  /// Returns up to [maxResults] place suggestions for [query].
  /// Pass [nearLat]/[nearLng] to bias results toward the user's location.
  static Future<List<MapplsPlaceSuggestion>> autocomplete(
    String query, {
    double? nearLat,
    double? nearLng,
    int maxResults = 5,
  }) async {
    if (query.trim().length < 2) return [];

    final token = await _getToken();
    if (token == null) return [];

    try {
      final params = <String, String>{
        'query': query.trim(),
        'region': 'IND',
      };
      if (nearLat != null && nearLng != null) {
        params['location'] = '$nearLat,$nearLng';
      }

      final uri = Uri.https(
        'atlas.mappls.com',
        '/api/places/search/json',
        params,
      );

      final res = await http.get(
        uri,
        headers: {'Authorization': 'bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);

      // The API may return suggestedLocations or suggestedSearches
      final raw = body['suggestedLocations'] as List? ??
          body['suggestedSearches'] as List? ??
          [];

      final suggestions = raw.take(maxResults).map((item) {
        final lat = (item['latitude']  as num?)?.toDouble() ??
                    (item['lat']       as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble() ??
                    (item['lng']       as num?)?.toDouble();
        return MapplsPlaceSuggestion(
          eLoc:         item['eLoc']?.toString()         ?? '',
          placeName:    item['placeName']?.toString()    ??
                        item['description']?.toString()  ?? query,
          placeAddress: item['placeAddress']?.toString() ??
                        item['detailedAddress']?.toString() ?? '',
          latitude:     lat,
          longitude:    lng,
        );
      }).toList();

      return suggestions;
    } catch (e) {
      debugPrint('Mappls autocomplete error: $e');
      return [];
    }
  }

  // ── Place detail (lat/lng from eLoc) ─────────────────────
  /// Resolves coordinates for a place using its eLoc.
  /// Use this when autocomplete didn't include lat/lng directly.
  static Future<MapplsPlaceSuggestion?> placeDetail(String eLoc) async {
    if (eLoc.isEmpty) return null;

    final token = await _getToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse(
          'https://atlas.mappls.com/api/places/geocode?region=IND&address=$eLoc');

      final res = await http.get(
        uri,
        headers: {'Authorization': 'bearer $token'},
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      final results = body['copResults'] as Map<String, dynamic>?;
      if (results == null) return null;

      final lat = (results['latitude']  as num?)?.toDouble();
      final lng = (results['longitude'] as num?)?.toDouble();

      return MapplsPlaceSuggestion(
        eLoc:         eLoc,
        placeName:    results['formattedAddress']?.toString() ?? eLoc,
        placeAddress: results['city']?.toString()             ?? '',
        latitude:     lat,
        longitude:    lng,
      );
    } catch (e) {
      debugPrint('Mappls place detail error: $e');
      return null;
    }
  }
}
