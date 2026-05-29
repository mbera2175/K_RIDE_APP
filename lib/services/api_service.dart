import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static final String _base = AppConstants.baseUrl;
  static const _timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${AuthService.token}',
  };

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
      if (data['detail'] is String)    error = data['detail'];
      else if (data['detail'] is List) error = (data['detail'] as List).join(', ');
    }
    return {'success': false, 'error': error, 'status': res.statusCode};
  }

  // ═══════════════════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════════════════

  /// Send OTP — now includes role ('rider' or 'driver')
  static Future<Map<String, dynamic>> sendOtp(String phone, String role) async {
    final res = await http.post(Uri.parse('$_base/auth/otp/send'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'role': role}))
      .timeout(_timeout);
    return _handle(res);
  }

  /// OTP Login — now includes role ('rider' or 'driver')
  static Future<Map<String, dynamic>> otpLogin(
      String phone, String otp, String role) async {
    final res = await http.post(Uri.parse('$_base/auth/otp/login'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'otp': otp, 'role': role}))
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
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DOCUMENTS — unchanged
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> uploadDocument({
    required int    driverId,
    required String docType,
    required File   file,
  }) async {
    try {
      final uri     = Uri.parse('$_base/documents/upload/$driverId/$docType');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${AuthService.token}';
      request.files.add(await http.MultipartFile.fromPath(
        'file', file.path, filename: '$docType.jpg'));
      final streamed = await request.send().timeout(_timeout);
      final res      = await http.Response.fromStream(streamed);
      return _handle(res);
    } catch (e) {
      return {'success': false, 'error': 'Upload failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> saveDocumentDetails({
    required int driverId,
    String? rcNumber, int? rcRegYear, int? rcExpireYear,
    String? dlNumber, int? dlExpireYear, String? aadhaarNumber,
  }) async {
    try {
      final String? licenseExpiry = dlExpireYear != null ? '$dlExpireYear-01-01' : null;
      final res = await http.post(
        Uri.parse('$_base/documents/details/$driverId'),
        headers: _authHeaders,
        body: jsonEncode({
          if (rcNumber      != null) 'rc_number'        : rcNumber,
          if (rcRegYear     != null) 'registration_year': rcRegYear,
          if (rcExpireYear  != null) 'rc_expiry_year'   : rcExpireYear,
          if (dlNumber      != null) 'license_number'   : dlNumber,
          if (licenseExpiry != null) 'license_expiry'   : licenseExpiry,
          if (aadhaarNumber != null) 'aadhaar_number'   : aadhaarNumber,
        }),
      ).timeout(_timeout);
      return _handle(res);
    } catch (e) {
      return {'success': false, 'error': 'Failed to save details: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDocuments(int driverId) async {
    final res = await http.get(
      Uri.parse('$_base/documents/$driverId'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  RIDER — unchanged
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> estimateFare({
    required double pickupLat, required double pickupLng,
    required double dropLat,   required double dropLng,
    required String vehicleType, String serviceType = 'ride',
  }) async {
    final res = await http.post(Uri.parse('$_base/trips/estimate'),
      headers: _authHeaders,
      body: jsonEncode({
        'pickup_lat': pickupLat, 'pickup_lng': pickupLng,
        'drop_lat'  : dropLat,  'drop_lng'  : dropLng,
        'vehicle_type': vehicleType, 'service_type': serviceType,
      })).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> bookTrip(Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$_base/trips/book'),
      headers: _authHeaders, body: jsonEncode(body)).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getActiveTrip() async {
    final res = await http.get(Uri.parse('$_base/trips/active'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getRiderHistory(
      {int limit = 20, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$_base/trips/my?limit=$limit&offset=$offset'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelRiderTrip(
      int tripId, String reason) async {
    final res = await http.patch(Uri.parse('$_base/trips/$tripId/cancel'),
      headers: _authHeaders, body: jsonEncode({'reason': reason}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> rateDriver(
      int tripId, int score, String? comment) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/rate'),
      headers: _authHeaders,
      body: jsonEncode({'score': score, 'comment': comment}))
      .timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DRIVER — unchanged
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> updateLocation(
      double lat, double lng) async {
    final res = await http.patch(
      Uri.parse('$_base/auth/driver/location?lat=$lat&lng=$lng'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> toggleOnline() async {
    final res = await http.patch(
      Uri.parse('$_base/auth/driver/toggle-online'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getAvailableTrips() async {
    final res = await http.get(
      Uri.parse('$_base/trips/driver/available'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDriverActiveTrip() async {
    final res = await http.get(Uri.parse('$_base/trips/driver/active'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> acceptTrip(int tripId) async {
    final res = await http.patch(
      Uri.parse('$_base/trips/$tripId/accept'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markArrived(int tripId) async {
    final res = await http.patch(
      Uri.parse('$_base/trips/$tripId/arrived'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> startTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/trips/$tripId/start'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> completeTrip(int tripId) async {
    final res = await http.patch(Uri.parse('$_base/trips/$tripId/complete'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelDriverTrip(
      int tripId, String reason) async {
    final res = await http.patch(Uri.parse('$_base/trips/$tripId/cancel'),
      headers: _authHeaders, body: jsonEncode({'reason': reason}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getEarningsSummary() async {
    final res = await http.get(
      Uri.parse('$_base/driver/earnings'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> requestWithdrawal(
      double amount, String? upiId) async {
    final res = await http.post(Uri.parse('$_base/payments/withdraw'),
      headers: _authHeaders,
      body: jsonEncode({'amount': amount, 'upi_id': upiId}))
      .timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getDriverHistory(
      {int limit = 20, int offset = 0}) async {
    final res = await http.get(
      Uri.parse('$_base/trips/driver/my?limit=$limit&offset=$offset'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  SHARED — unchanged
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getNotifications(
      {bool unread = false}) async {
    final res = await http.get(
      Uri.parse('$_base/notifications/?unread_only=$unread'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markAllRead() async {
    final res = await http.patch(
      Uri.parse('$_base/notifications/read-all'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletBalance() async {
    final res = await http.get(Uri.parse('$_base/wallet/'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getWalletTransactions() async {
    final res = await http.get(Uri.parse('$_base/wallet/transactions'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> addMoneyToWallet(double amount) async {
    final res = await http.post(Uri.parse('$_base/wallet/add'),
      headers: _authHeaders, body: jsonEncode({'amount': amount}))
      .timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  BONUS SYSTEM
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> addBonus(int tripId, double bonusAmount) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/bonus'),
      headers: _authHeaders,
      body: jsonEncode({'bonus_amount': bonusAmount})).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  K COINS
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getKCoinConfig() async {
    final res = await http.get(Uri.parse('$_base/wallet/kcoin-config'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  SOS
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> raiseSOS(int tripId) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/sos'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  CHAT
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> sendChatMessage(
      int tripId, String messageType, String? messageText, String? quickMsgKey) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/chat'),
      headers: _authHeaders,
      body: jsonEncode({
        'message_type' : messageType,
        'message_text' : messageText,
        'quick_msg_key': quickMsgKey,
      })).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getChatMessages(int tripId) async {
    final res = await http.get(Uri.parse('$_base/trips/$tripId/chat'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getQuickMessages() async {
    final res = await http.get(Uri.parse('$_base/quick-messages'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  TRIP SHARE
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> createTripShare(int tripId) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/share'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> trackSharedTrip(String shareCode) async {
    final res = await http.get(Uri.parse('$_base/track/$shareCode'),
      headers: _headers).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DISPUTE
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> raiseDispute(int tripId, String reason) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/dispute'),
      headers: _authHeaders,
      body: jsonEncode({'reason': reason})).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  BLACKLIST
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> blacklistDriver(int driverId) async {
    final res = await http.post(Uri.parse('$_base/drivers/$driverId/blacklist'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getBlacklist() async {
    final res = await http.get(Uri.parse('$_base/blacklist'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  TRIP RECEIPT & EARNINGS
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getTripReceipt(int tripId) async {
    final res = await http.get(Uri.parse('$_base/trips/$tripId/receipt'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> getTripEarnings(int tripId) async {
    final res = await http.get(Uri.parse('$_base/trips/$tripId/earnings'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  DRIVER ACTIONS
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> rejectTrip(int tripId) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/reject'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  static Future<Map<String, dynamic>> markCashCollected(int tripId) async {
    final res = await http.post(Uri.parse('$_base/trips/$tripId/cash-collected'),
      headers: _authHeaders).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  PRICING
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getPricing(String city) async {
    final res = await http.get(Uri.parse('$_base/pricing/?city=$city'),
      headers: _headers).timeout(_timeout);
    return _handle(res);
  }

  // ═══════════════════════════════════════════════════════
  //  PROMOS
  // ═══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> getActivePromos() async {
    final res = await http.get(Uri.parse('$_base/promos/active'),
      headers: _headers).timeout(_timeout);
    return _handle(res);
  }
}
