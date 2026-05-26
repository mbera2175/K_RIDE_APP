import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../main.dart';
import '../screens/auth/role_selection_screen.dart';

class AuthService {
  static SharedPreferences? _prefs;

  // ── Init ────────────────────────────────────────────────
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Save after login/register ───────────────────────────
  static Future<void> saveSession(Map<String, dynamic> data) async {
    await _prefs?.setString(AppConstants.keyToken,  data['access_token'] ?? '');
    await _prefs?.setString(AppConstants.keyRole,   data['role']         ?? '');
    await _prefs?.setString(AppConstants.keyName,   data['full_name']    ?? '');
    await _prefs?.setString(AppConstants.keyPhone,  data['phone']        ?? '');
    await _prefs?.setInt(   'user_id',              data['user_id']      ?? 0);
    await _prefs?.setDouble('wallet_balance', (data['wallet_balance'] ?? 0.0).toDouble());

    if (data['driver_id'] != null) {
      await _prefs?.setInt('driver_id', data['driver_id']);
    }
    if (data['rider_id'] != null) {
      await _prefs?.setInt('rider_id', data['rider_id']);
    }
    if (data['language'] != null) {
      await _prefs?.setString(AppConstants.keyLanguage, data['language']);
    }

    // ── Driver fields ──────────────────────────────────────
    if (data['is_approved'] != null) {
      await _prefs?.setBool('is_approved', data['is_approved'] == true);
    }

    // ── Role-specific block status ─────────────────────────
    // rider blocked as rider only
    if (data['is_blocked_as_rider'] != null) {
      await _prefs?.setBool('is_blocked_as_rider', data['is_blocked_as_rider'] == true);
    }
    // driver blocked as driver only
    if (data['is_blocked_as_driver'] != null) {
      await _prefs?.setBool('is_blocked_as_driver', data['is_blocked_as_driver'] == true);
    }

    // ── Profile picture ────────────────────────────────────
    final picUrl = (data['profile_pic'] ?? data['profile_pic_url'] ?? '') as String;
    if (picUrl.isNotEmpty) {
      await _prefs?.setString('profile_pic', picUrl);
    }
  }

  // ── Getters ─────────────────────────────────────────────
  static String get token         => _prefs?.getString(AppConstants.keyToken)    ?? '';
  static String get role          => _prefs?.getString(AppConstants.keyRole)     ?? '';
  static String get name          => _prefs?.getString(AppConstants.keyName)     ?? '';
  static String get phone         => _prefs?.getString(AppConstants.keyPhone)    ?? '';
  static String get language      => _prefs?.getString(AppConstants.keyLanguage) ?? 'en';
  static int    get userId        => _prefs?.getInt('user_id')                   ?? 0;
  static int    get driverId      => _prefs?.getInt('driver_id')                 ?? 0;
  static int    get riderId       => _prefs?.getInt('rider_id')                  ?? 0;
  static double get walletBalance => _prefs?.getDouble('wallet_balance')         ?? 0.0;
  static bool   get isLoggedIn    => token.isNotEmpty;
  static bool   get isDriver      => role == 'driver';
  static bool   get isRider       => role == 'rider';
  static bool   get isApproved    => _prefs?.getBool('is_approved')              ?? false;
  static String get profilePic    => _prefs?.getString('profile_pic')            ?? '';

  // ── Role-specific block status ───────────────────────────
  static bool get isBlockedAsRider  => _prefs?.getBool('is_blocked_as_rider')  ?? false;
  static bool get isBlockedAsDriver => _prefs?.getBool('is_blocked_as_driver') ?? false;

  // ── Update wallet locally ────────────────────────────────
  static Future<void> updateWallet(double balance) async {
    await _prefs?.setDouble('wallet_balance', balance);
  }

  // ── Update approval & profile pic locally ────────────────
  static Future<void> updateApprovalStatus(bool approved) async {
    await _prefs?.setBool('is_approved', approved);
  }


  static Future<void> updateProfilePic(String url) async {
    await _prefs?.setString('profile_pic', url);
  }

  // ── Logout ───────────────────────────────────────────────
  static Future<void> logout({bool forced = false}) async {
    await _prefs?.clear();
    if (forced) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }
}
