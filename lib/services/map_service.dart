import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mappls_gl/mappls_gl.dart';
import '../utils/constants.dart';

class MapService {
  static const String _restApiKey = AppConstants.mapplsRestAPIKey;

  /// Fetches route between source and destination and returns a list of points
  static Future<List<LatLng>> getRoute(LatLng source, LatLng destination) async {
    final String url = "https://apis.mappls.com/advancedmaps/v1/$_restApiKey/route_adv/driving/${source.longitude},${source.latitude};${destination.longitude},${destination.latitude}?full_geometry=polyline&overview=full";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          return _decodePolyline(data['routes'][0]['geometry']);
        }
      }
    } catch (e) {
      print("Route error: $e");
    }
    return [];
  }

  /// Decodes Mappls encoded polyline into list of LatLng
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
