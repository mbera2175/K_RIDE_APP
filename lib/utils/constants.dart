import 'package:flutter/material.dart';

class AppConstants {
  // ── API ──────────────────────────────────────────────
  static const String baseUrl = 'https://kridebackend-production.up.railway.app';

  // ── App Info ─────────────────────────────────────────
  static const String appName    = 'KRide';
  static const String appVersion = '1.0.0';
  static const String currency   = '₹';
  static const String countryCode= '+91';

  // ── Storage Keys ─────────────────────────────────────
  static const String keyToken    = 'auth_token';
  static const String keyUserId   = 'user_id';
  static const String keyRole     = 'user_role';
  static const String keyName     = 'user_name';
  static const String keyPhone    = 'user_phone';
  static const String keyLanguage = 'app_language';

  // ── Languages ────────────────────────────────────────
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English',  'native': 'English'},
    {'code': 'hi', 'name': 'Hindi',    'native': 'हिन्दी'},
    {'code': 'bn', 'name': 'Bengali',  'native': 'বাংলা'},
  ];

  // ── Vehicle Types ─────────────────────────────────────
  static const List<Map<String, dynamic>> vehicleTypes = [
    {'type': 'bike',       'label': 'Bike',        'icon': Icons.two_wheeler_rounded,       'capacity': 1},
    {'type': 'cab_ac',     'label': 'Cab AC',      'icon': Icons.ac_unit_rounded,           'capacity': 4},
    {'type': 'cab_non_ac', 'label': 'Cab Non AC',  'icon': Icons.directions_car_rounded,    'capacity': 4},
    {'type': 'auto',       'label': 'Auto',        'icon': Icons.local_taxi_rounded,        'capacity': 3},
    {'type': 'toto',       'label': 'Toto',        'icon': Icons.electric_rickshaw_rounded, 'capacity': 3},
    {'type': 'ambulance',  'label': 'Ambulance',   'icon': Icons.medical_services_rounded,  'capacity': 2},
  ];

  // ── Services ──────────────────────────────────────────
  static const List<Map<String, dynamic>> services = [
    {'type': 'parcel',    'label': 'Parcel',    'icon': Icons.local_shipping_rounded},
    {'type': 'food',      'label': 'Food',      'icon': Icons.restaurant_rounded},
    {'type': 'medicine',  'label': 'Medicine',  'icon': Icons.medical_information_rounded},
  ];
}
