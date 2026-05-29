import 'package:flutter/material.dart';

class AppConstants {
  // ── API ──────────────────────────────────────────────
  static const String baseUrl = 'http://13.232.171.208:8000';

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
    {'type': 'bike',        'label': 'Bike',        'emoji': '🏍️', 'capacity': 1},
    {'type': 'auto',        'label': 'Auto',        'emoji': '🛺',  'capacity': 3},
    {'type': 'toto',        'label': 'Toto',        'emoji': '🛵',  'capacity': 3},
    {'type': 'ac_cab',      'label': 'AC Cab',      'emoji': '🚖',  'capacity': 4},
    {'type': 'non_ac_cab',  'label': 'Non-AC Cab',  'emoji': '🚕',  'capacity': 4},
    {'type': 'ambulance',   'label': 'Ambulance',   'emoji': '🚑',  'capacity': 2},
  ];

  // ── Fuel Types ────────────────────────────────────────
  static const List<Map<String, String>> fuelTypes = [
    {'type': 'petrol',  'label': 'Petrol'},
    {'type': 'diesel',  'label': 'Diesel'},
    {'type': 'gas',     'label': 'Gas/CNG'},
    {'type': 'ev',      'label': 'Electric (EV)'},
    {'type': 'hybrid',  'label': 'Hybrid'},
  ];

  // ── Cities ────────────────────────────────────────────
  static const List<String> cities = [
    'Bardhaman',
    'Kolkata',
    'Medinipur',
  ];

  // ── Bonus Options ────────────────────────────────────
  static const List<int> bonusOptions = [10, 20, 30, 40, 50, 100];

  // ── WebSocket ────────────────────────────────────────
  static const String wsBaseUrl = 'ws://13.232.171.208:8000';

  // ── Services ──────────────────────────────────────────
  static const List<Map<String, dynamic>> services = [
    {'type': 'parcel',    'label': 'Parcel',    'icon': Icons.local_shipping_rounded},
    {'type': 'food',      'label': 'Food',      'icon': Icons.restaurant_rounded},
    {'type': 'medicine',  'label': 'Medicine',  'icon': Icons.medical_information_rounded},
  ];
}
