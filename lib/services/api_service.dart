import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static final String _base = AppConstants.baseUrl;

  // ── Timeout duration for all requests ───────────────────
  static const _timeout = Duration(seconds: 30);

  // ── Headers ─────────────────────────────────────────────
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AuthService.token}',
  };

  // ── Generic request handler ──────────────────────────────
  static Future<Map<String, dynamic>> _handle(http.Response res) async {
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return {'success': true, 'data': data, 'status': res.statusCode};
    }
    if (res.statusCode == 403) {
      final detail = data is Map ? data['detail'] : '';
      if (detail != null && detail.toString().contains('another device')) {
        await AuthService.logout();
        return {
          'success': false,
          'error': 'You have been logged out because your account was accessed from another device.',
          'status': 403,
          'force_logout': true
        };
      }
    }
    String error = 'Something went wrong';
    if (data is Map) {
      if (data['detail'] is String)      error = data['detail'];
      else if (data['detail'] is List)   error = (data['detail'] as List).join(', ');
    }
    return {'success': false, 'error': error, 'status': res.statusCode};
  }

  // ═══════════════════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> sendOtp(String phone, String role) async {
    final res = await http.post(Uri.parse('$_base/auth/otp/send'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'role': role}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> otpLogin(String phone, String otp) async {
    final res = await http.post(Uri.parse('$_base/auth/otp/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'otp': otp}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> passwordLogin(String phone, String password) async {
    final res = await http.post(Uri.parse('$_base/auth/password/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'password': password}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> registerRider(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/auth/register/rider'),
      headers: _headers, body: jsonEncode(body))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> registerDriver(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/auth/register/driver'),
      headers: _headers, body: jsonEncode(body))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(Uri.parse('$_base/auth/me'),
      headers: _authHeaders)
      .timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DOCUMENTS
  // ═══════════════════════════════════════════════════════

  /// Upload a single document image to Cloudinary via backend.
  /// [driverId] — the driver's ID returned after registration
  /// [docType]  — one of: dl_front, dl_back, rc_front, rc_back,
  ///              aadhaar_front, aadhaar_back, insurance, permit, profile_pic
  /// [file]     — the image File picked from camera or gallery
  static Future<Map<String, dynamic>> uploadDocument({
    required int    driverId,
    required String docType,
    required File   file,
  }) async {
    try {
      final uri = Uri.parse('$_base/documents/upload/$driverId/$docType');
      final request = http.MultipartRequest('POST', uri);

      // Auth header
      request.headers['Authorization'] = 'Bearer ${AuthService.token}';

      // Attach file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: '$docType.jpg',
      ));

      final streamed = await request.send().timeout(_timeout);
      final res      = await http.Response.fromStream(streamed);
      return _handle(res);

    } catch (e) {
      return {'success': false, 'error': 'Upload failed: $e'};
    }
  }

  /// Save text document details (RC number, DL number, Aadhaar number, years).
  /// FIX: Field names now match backend DocumentDetailsReq schema exactly.
  /// Backend expects: license_number (str), license_expiry (YYYY-MM-DD string)
  static Future<Map<String, dynamic>> saveDocumentDetails({
    required int    driverId,
    String?         rcNumber,
    int?            rcRegYear,
    int?            rcExpireYear,
    String?         dlNumber,       // sent as 'license_number' to backend
    int?            dlExpireYear,   // converted to 'license_expiry' YYYY-MM-DD
    String?         aadhaarNumber,
  }) async {
    try {
      // Convert dlExpireYear integer to YYYY-MM-DD string backend expects
      // e.g. 2026 → "2026-01-01"
      final String? licenseExpiry = dlExpireYear != null
          ? '$dlExpireYear-01-01'
          : null;

      final res = await http.post(
        Uri.parse('$_base/documents/details/$driverId'),
        headers: _authHeaders,
        body: jsonEncode({
          if (rcNumber      != null) 'rc_number'        : rcNumber,
          if (rcRegYear     != null) 'registration_year': rcRegYear,
          if (rcExpireYear  != null) 'rc_expiry_year'   : rcExpireYear,
          if (dlNumber      != null) 'license_number'   : dlNumber,   // ✅ FIXED
          if (licenseExpiry != null) 'license_expiry'   : licenseExpiry, // ✅ FIXED
          if (aadhaarNumber != null) 'aadhaar_number'   : aadhaarNumber,
        }),
      ).timeout(_timeout);
      return _handle(res);
    } catch (e) {
      return {'success': false, 'error': 'Failed to save details: $e'};
    }
  }

  /// Get all uploaded document URLs for a driver.
  static Future<Map<String, dynamic>> getDocuments(int driverId) async {
    final res = await http.get(
      Uri.parse('$_base/documents/$driverId'),
      headers: _authHeaders,
    ).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  RIDER
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> estimateFare({
    required double pickupLat, required double pickupLng,
    required double dropLat,   required double dropLng,
    required String vehicleType,
    String serviceType = 'ride',
  }) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/estimate'),
      headers: _authHeaders,
      body: jsonEncode({
        'pickup_lat'  : pickupLat,  'pickup_lng': pickupLng,
        'drop_lat'    : dropLat,    'drop_lng'  : dropLng,
        'vehicle_type': vehicleType,'service_type': serviceType,
      })).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> bookTrip(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/book'),
      headers: _authHeaders, body: jsonEncode(body))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getActiveTrip() async {
    final res = await http.get(Uri.parse('$_base/rider/trips/active'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getRiderHistory({int limit = 20, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$_base/rider/trips/history?limit=$limit&offset=$offset'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelRiderTrip(int tripId, String reason) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/$tripId/cancel'),
      headers: _authHeaders, body: jsonEncode({'reason': reason}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rateDriver(int tripId, int score, String? comment) async {
    final res = await http.post(Uri.parse('$_base/rider/trips/$tripId/rate'),
      headers: _authHeaders,
      body: jsonEncode({'score': score, 'comment': comment}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> applyPromo(String code, double fare) async {
    final res = await http.get(
      Uri.parse('$_base/rider/promo/apply?code=$code&fare=$fare'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getSavedAddresses() async {
    final res = await http.get(Uri.parse('$_base/rider/addresses'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DRIVER
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    final res = await http.patch(
      Uri.parse('$_base/driver/location?lat=$lat&lng=$lng'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> toggleOnline() async {
    final res = await http.patch(Uri.parse('$_base/driver/toggle-online'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getAvailableTrips() async {
    final res = await http.get(Uri.parse('$_base/driver/trips/available'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDriverActiveTrip() async {
    final res = await http.get(Uri.parse('$_base/driver/trips/active'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> acceptTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/accept'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markArrived(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/arrived'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> startTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/start'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> completeTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/complete'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelDriverTrip(int tripId, String reason) async {
    final res = await http.patch(Uri.parse('$_base/driver/trips/$tripId/cancel'),
      headers: _authHeaders, body: jsonEncode({'reason': reason}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getEarningsSummary() async {
    final res = await http.get(Uri.parse('$_base/driver/earnings/summary'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> requestWithdrawal(
      double amount, String? upiId) async {
    final res = await http.post(Uri.parse('$_base/driver/earnings/withdraw'),
      headers: _authHeaders,
      body: jsonEncode({'amount': amount, 'upi_id': upiId}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDriverHistory({int limit = 20, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$_base/driver/trips/history?limit=$limit&offset=$offset'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  SHARED
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getNotifications({bool unread = false}) async {
    final res = await http.get(
      Uri.parse('$_base/notifications?unread_only=$unread'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markAllRead() async {
    final res = await http.patch(Uri.parse('$_base/notifications/read-all'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await http.get(Uri.parse('$_base/wallet/balance'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletTransactions() async {
    final res = await http.get(Uri.parse('$_base/wallet/transactions'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> addMoneyToWallet(double amount) async {
    final res = await http.post(Uri.parse('$_base/wallet/add-money'),
      headers: _authHeaders, body: jsonEncode({'amount': amount}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createSupportTicket(
      String category, String subject, String message, {int? tripId}) async {
    final res = await http.post(Uri.parse('$_base/support/tickets'),
      headers: _authHeaders,
      body: jsonEncode({
        'category': category, 'subject': subject,
        'message': message,   'trip_id': tripId,
      })).timeout(_timeout);
    return _handle(res);
  }
}
