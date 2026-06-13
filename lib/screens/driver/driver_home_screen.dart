import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/driver_socket_service.dart';
import '../../services/ride_alert_service.dart';
import '../auth/role_selection_screen.dart';
import 'my_documents_screen.dart';
import '../../services/map_service.dart';

// ── Colour tokens ────────────────────────────────────────────
const kOrange = Color(0xFFFF6B00);
const kOrangeDark = Color(0xFFE55A00);
const kOrangeLight = Color(0xFFFFF3E8);
const kWhite = Color(0xFFFFFFFF);
const kGray = Color(0xFFF6F6F6);
const kGray2 = Color(0xFFEEEEEE);
const kDark = Color(0xFF1A1A1A);
const kMuted = Color(0xFF9E9E9E);
const kSuccess = Color(0xFF00C853);
const kError = Color(0xFFFF3B3B);
const kInfo = Color(0xFF3B82F6);
const kScaffoldBg = Color(0xFFF5F5F5);

// ── Data models ──────────────────────────────────────────────
class TripData {
  final int id;
  final String tripCode;
  final int fare;
  final int driverEarnings;
  final String pickup;
  final String drop;
  final String distance;
  final String duration;

  final double pickupDistanceKm;
  final double tripDistanceKm;

  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;

  final String payment;
  final String riderRating;
  final String riderName;
  final String riderPhone;
  final String riderPhotoUrl;
  final String vehicle;
  final double bonusAmount;
  final double totalFare;
  final bool isNonAcRequest;
  final String message;
  String status; // requested | accepted | arrived | started

  final String? promoCode;
  final double promoDiscount;
  final double actualFare;

  TripData({
    required this.id,
    required this.tripCode,
    required this.fare,
    required this.driverEarnings,
    required this.pickup,
    required this.drop,
    required this.distance,
    required this.duration,
    required this.pickupDistanceKm,
    required this.tripDistanceKm,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    required this.payment,
    required this.riderRating,
    required this.riderName,
    required this.riderPhone,
    required this.riderPhotoUrl,
    required this.vehicle,
    required this.bonusAmount,
    required this.totalFare,
    required this.isNonAcRequest,
    required this.message,
    required this.status,
    this.promoCode,
    required this.promoDiscount,
    required this.actualFare,
  });

  TripData copyWith({
    String? status,
    double? pickupDistanceKm,
    double? tripDistanceKm,
  }) =>
      TripData(
        id: id,
        tripCode: tripCode,
        fare: fare,
        driverEarnings: driverEarnings,
        pickup: pickup,
        drop: drop,
        distance: distance,
        duration: duration,
        pickupDistanceKm: pickupDistanceKm ?? this.pickupDistanceKm,
        tripDistanceKm: tripDistanceKm ?? this.tripDistanceKm,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropLat: dropLat,
        dropLng: dropLng,
        payment: payment,
        riderRating: riderRating,
        riderName: riderName,
        riderPhone: riderPhone,
        riderPhotoUrl: riderPhotoUrl,
        vehicle: vehicle,
        bonusAmount: bonusAmount,
        totalFare: totalFare,
        isNonAcRequest: isNonAcRequest,
        message: message,
        status: status ?? this.status,
        promoCode: promoCode,
        promoDiscount: promoDiscount,
        actualFare: actualFare,
      );
}

class EarningsData {
  final String wallet;
  final String today;
  final String week;
  final String month;
  final String allTime;
  final int trips;
  const EarningsData({
    required this.wallet,
    required this.today,
    required this.week,
    required this.month,
    required this.allTime,
    required this.trips,
  });
}

Map<String, dynamic> _unwrapTripPayload(dynamic raw) {
  final normalized = _maybeDecodeJson(raw);
  if (normalized is! Map<String, dynamic>) {
    return <String, dynamic>{};
  }

  var current = Map<String, dynamic>.from(normalized);

  while (true) {
    final nested = _maybeDecodeJson(_firstValue(current, const [
      'trip',
      'booking',
      'ride',
      'ride_request',
      'request',
      'payload',
      'data',
    ]));

    if (nested is! Map<String, dynamic>) {
      break;
    }

    final nestedMap = Map<String, dynamic>.from(nested);
    final hasBookingFields = nestedMap.keys.any(
      (key) => const {
        'id',
        'trip_id',
        'booking_id',
        'trip_code',
        'pickup_address',
        'drop_address',
        'estimated_fare',
        'fare',
        'pickup_distance_km',
        'distance_km',
      }.contains(key),
    );

    current = nestedMap;
    if (hasBookingFields) {
      break;
    }
  }

  return current;
}

dynamic _firstValue(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value != null) return value;
  }
  return null;
}

dynamic _maybeDecodeJson(dynamic raw) {
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return raw;
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        return jsonDecode(text);
      } catch (_) {
        return raw;
      }
    }
  }
  return raw;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString()) ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

String _asText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _normalizeTripStatus(dynamic value, {String fallback = 'requested'}) {
  var text = _asText(value, fallback: fallback).trim().toLowerCase();
  if (text.contains('.')) text = text.split('.').last;
  if (text == 'driver_assigned' || text == 'trip_accepted' || text == 'accepted') {
    return 'accepted';
  }
  if (text == 'driver_arrived' || text == 'arrived') {
    return 'arrived';
  }
  if (text == 'trip_started' || text == 'on_trip' || text == 'ontrip' || text == 'started') {
    return 'started';
  }
  if (text == 'trip_completed' || text == 'completed') {
    return 'completed';
  }
  if (text == 'trip_cancelled' || text == 'cancelled') {
    return 'cancelled';
  }
  return text.isEmpty ? fallback : text;
}

TripData _mapToTripData(dynamic raw) {
  final data = _unwrapTripPayload(raw);

  final fare = _asInt(
    _firstValue(
      data,
      const ['total_fare', 'estimated_fare', 'fare', 'amount', 'trip_fare'],
    ),
  );
  final driverEarnings = _asInt(
    _firstValue(data, const ['driver_earnings', 'driver_earning', 'earnings']),
    fallback: fare,
  );
  final pickupDistance = _asDouble(
    _firstValue(data, const [
      'pickup_distance_km',
      'driver_to_pickup_distance_km',
      'distance_to_pickup_km',
      'distance_to_pickup',
      'driver_distance_km',
      'pickup_distance',
    ]),
  );
  final tripDistance = _asDouble(
    _firstValue(
        data, const ['distance_km', 'trip_distance_km', 'ride_distance_km']),
  );

  return TripData(
    id: _asInt(_firstValue(data, const ['id', 'trip_id', 'booking_id'])),
    tripCode: _asText(
      _firstValue(data, const ['trip_code', 'code', 'booking_code']),
      fallback: '#${_asInt(_firstValue(data, const [
            'id',
            'trip_id',
            'booking_id'
          ]))}',
    ),
    fare: fare,
    driverEarnings: driverEarnings,
    pickup: _asText(
      _firstValue(data, const [
        'pickup_address',
        'pickup',
        'pickup_location',
        'origin',
        'source'
      ]),
      fallback: 'Pickup location',
    ),
    drop: _asText(
      _firstValue(data, const [
        'drop_address',
        'drop',
        'drop_location',
        'destination',
        'target'
      ]),
      fallback: 'Drop location',
    ),
    distance: tripDistance > 0 ? tripDistance.toStringAsFixed(1) : '0',
    duration: _asText(
        _firstValue(data, const ['duration_min', 'duration', 'eta_min']),
        fallback: '0'),
    pickupDistanceKm: pickupDistance,
    tripDistanceKm: tripDistance,
    pickupLat: _asDouble(_firstValue(data, const ['pickup_lat', 'pickup_latitude', 'lat'])),
    pickupLng: _asDouble(_firstValue(data, const ['pickup_lng', 'pickup_longitude', 'lng'])),
    dropLat: _asDouble(_firstValue(data, const ['drop_lat', 'drop_latitude'])),
    dropLng: _asDouble(_firstValue(data, const ['drop_lng', 'drop_longitude'])),
    payment: _asText(
        _firstValue(data, const ['payment_method', 'payment', 'payment_type']),
        fallback: 'Cash'),
    riderRating: '5.0',
    riderName: data['rider'] is Map<String, dynamic>
        ? _asText((data['rider'] as Map<String, dynamic>)['name'],
            fallback: 'Rider')
        : _asText(_firstValue(data, const ['rider_name', 'rider']),
            fallback: 'Rider'),
    riderPhone: data['rider'] is Map<String, dynamic>
        ? _asText((data['rider'] as Map<String, dynamic>)['phone'])
        : _asText(_firstValue(data, const ['rider_phone', 'phone'])),
    riderPhotoUrl: data['rider'] is Map<String, dynamic>
        ? _asText(
            (data['rider'] as Map<String, dynamic>)['profile_pic'] ??
                (data['rider'] as Map<String, dynamic>)['profile_pic_url'] ??
                (data['rider'] as Map<String, dynamic>)['profile_photo'] ??
                (data['rider'] as Map<String, dynamic>)['profile_picture_url'],
            fallback: '')
        : _asText(
            _firstValue(data, const [
              'rider_profile_pic',
              'rider_profile_photo',
              'rider_photo_url',
              'rider_profile_pic_url',
              'profile_pic'
            ]),
            fallback: ''),
    vehicle: _asText(
            _firstValue(
                data, const ['vehicle_type', 'vehicle', 'service_type']),
            fallback: 'cab')
        .toUpperCase(),
    bonusAmount: _asDouble(
      _firstValue(data, const ['bonus_amount', 'bonus', 'bonus_fare']),
    ),
    totalFare: _asDouble(
      _firstValue(data, const ['total_fare', 'estimated_fare', 'fare']),
      fallback: fare.toDouble(),
    ),
    isNonAcRequest:
        _firstValue(data, const ['is_non_ac_request', 'non_ac_request']) ==
            true,
    message: _asText(_firstValue(data, const ['message', 'note', 'remarks'])),
    status: _normalizeTripStatus(
        _firstValue(data, const ['status', 'trip_status', 'booking_status']),
        fallback: 'requested'),
    promoCode: _asText(_firstValue(data, const ['promo_code', 'coupon_code'])),
    promoDiscount: _asDouble(_firstValue(data, const ['promo_discount', 'discount'])),
    actualFare: _asDouble(
      _firstValue(data, const ['actual_fare', 'rider_payable', 'net_fare']),
      fallback: (fare.toDouble() -
          _asDouble(_firstValue(data, const ['promo_discount', 'discount']))),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
//  ANIMATED MAP
// ══════════════════════════════════════════════════════════════
class MapPainter extends CustomPainter {
  final bool isOnline;
  final double t;
  final Offset driverPos;

  static const _roads = [
    [0.00, 0.30, 1.00, 0.30, 28.0],
    [0.00, 0.60, 1.00, 0.62, 22.0],
    [0.25, 0.00, 0.25, 1.00, 24.0],
    [0.65, 0.00, 0.65, 1.00, 20.0],
    [0.00, 0.15, 0.65, 0.15, 14.0],
    [0.25, 0.45, 1.00, 0.45, 16.0],
    [0.45, 0.30, 0.45, 1.00, 12.0],
    [0.80, 0.00, 0.80, 0.60, 14.0],
  ];

  static const _buildings = [
    [0.02, 0.02, 0.18, 0.12],
    [0.02, 0.18, 0.18, 0.10],
    [0.28, 0.02, 0.14, 0.10],
    [0.28, 0.18, 0.14, 0.26],
    [0.46, 0.02, 0.16, 0.10],
    [0.46, 0.18, 0.16, 0.10],
    [0.66, 0.02, 0.12, 0.26],
    [0.82, 0.02, 0.16, 0.12],
    [0.82, 0.18, 0.16, 0.10],
    [0.02, 0.64, 0.18, 0.18],
    [0.28, 0.48, 0.14, 0.14],
    [0.46, 0.48, 0.16, 0.14],
    [0.66, 0.48, 0.12, 0.14],
    [0.66, 0.64, 0.12, 0.18],
    [0.82, 0.64, 0.16, 0.18],
    [0.28, 0.64, 0.14, 0.18],
    [0.46, 0.64, 0.16, 0.18],
  ];

  const MapPainter(
      {required this.isOnline, required this.t, required this.driverPos});

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;
    final p = Paint();

    // Background
    p.color = isOnline ? const Color(0xFFF0F4FF) : const Color(0xFFF8F4EF);
    canvas.drawRect(Offset.zero & size, p);

    // Grid
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color =
          isOnline ? kOrange.withOpacity(0.07) : Colors.black.withOpacity(0.05);
    for (double x = 0; x < W; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, H), p);
    }
    for (double y = 0; y < H; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(W, y), p);
    }

    // Buildings
    p.style = PaintingStyle.fill;
    for (int i = 0; i < _buildings.length; i++) {
      final b = _buildings[i];
      final shade = (220 + (i % 4) * 6).clamp(0, 255).toDouble();
      p.color = Color.fromARGB(255, shade.toInt(),
          (shade - 2).clamp(0, 255).toInt(), (shade - 4).clamp(0, 255).toInt());
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(b[0] * W, b[1] * H, b[2] * W, b[3] * H),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, p);
      p
        ..style = PaintingStyle.stroke
        ..color = Colors.black.withOpacity(0.06)
        ..strokeWidth = 1;
      canvas.drawRRect(rrect, p);
      p.style = PaintingStyle.fill;
    }

    // Green park
    p.color = const Color(0xFFC8DDB8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(W * 0.47, H * 0.32, W * 0.16, H * 0.12),
          const Radius.circular(6)),
      p,
    );

    // Roads
    final roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFE8E0D5)
      ..strokeCap = StrokeCap.round;
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFB4AAA0).withOpacity(0.5)
      ..strokeWidth = 1;

    for (final r in _roads) {
      final p1 = Offset(r[0] * W, r[1] * H);
      final p2 = Offset(r[2] * W, r[3] * H);
      roadPaint.strokeWidth = r[4];
      canvas.drawLine(p1, p2, roadPaint);
      _drawDashedLine(canvas, p1, p2, dashPaint, 10, 8);
    }

    // Orange pulse on online roads
    if (isOnline) {
      final pulse = (sin(t * 0.002) + 1) / 2;
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final r = _roads[i];
        pulsePaint
          ..color = kOrange.withOpacity(0.06 + pulse * 0.08)
          ..strokeWidth = r[4] * 0.35;
        canvas.drawLine(
            Offset(r[0] * W, r[1] * H), Offset(r[2] * W, r[3] * H), pulsePaint);
      }
    }

    // Driver location
    final dpx = driverPos.dx * W;
    final dpy = driverPos.dy * H;
    final pulse2 = (sin(t * 0.003) + 1) / 2;

    canvas.drawCircle(Offset(dpx, dpy), 32 + pulse2 * 10,
        Paint()..color = kOrange.withOpacity(0.08 + pulse2 * 0.06));
    canvas.drawCircle(
        Offset(dpx, dpy), 20, Paint()..color = kOrange.withOpacity(0.18));
    canvas.drawCircle(Offset(dpx, dpy), 14, Paint()..color = kWhite);
    canvas.drawCircle(
        Offset(dpx, dpy),
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = kOrange
          ..strokeWidth = 2.5);

    // Car emoji via TextPainter
    final tp = TextPainter(
      text: const TextSpan(text: '🚗', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(dpx - tp.width / 2, dpy - 24 - tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint,
      double dashLen, double gapLen) {
    final total = (p2 - p1).distance;
    final dir = (p2 - p1) / total;
    double dist = 0;
    bool drawing = true;
    while (dist < total) {
      final segLen = (drawing ? dashLen : gapLen).clamp(0.0, total - dist);
      if (drawing) {
        canvas.drawLine(p1 + dir * dist, p1 + dir * (dist + segLen), paint);
      }
      dist += segLen;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.isOnline != isOnline || old.t != t || old.driverPos != driverPos;
}

class MapBackground extends StatefulWidget {
  final bool isOnline;
  final Offset driverPos;
  const MapBackground(
      {super.key, required this.isOnline, required this.driverPos});

  @override
  State<MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<MapBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMilliseconds.toDouble());
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MapPainter(
          isOnline: widget.isOnline, t: _t, driverPos: widget.driverPos),
      child: const SizedBox.expand(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  INCOMING TRIP MODAL
// ══════════════════════════════════════════════════════════════
class IncomingTripModal extends StatefulWidget {
  final TripData trip;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const IncomingTripModal(
      {super.key,
      required this.trip,
      required this.onAccept,
      required this.onDecline});

  @override
  State<IncomingTripModal> createState() => _IncomingTripModalState();
}

class _IncomingTripModalState extends State<IncomingTripModal>
    with SingleTickerProviderStateMixin {
  int _timer = 25;
  double _progress = 1.0;
  Timer? _countdown;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..forward();
    _slideAnim = Tween(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.elasticOut));

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timer--;
        _progress = (_timer / 25).clamp(0.0, 1.0);
        if (_timer <= 0) widget.onDecline();
      });
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.90;
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _slideAnim,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 40,
                      offset: Offset(0, -8))
                ],
                border: Border.all(color: kOrange.withOpacity(0.13)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 4,
                        color: kGray2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            widthFactor: _progress,
                            duration: const Duration(seconds: 1),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [kOrange, kOrangeDark]),
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: [
                                  BoxShadow(
                                      color: kOrange.withOpacity(0.53),
                                      blurRadius: 6)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NEW RIDE REQUEST 🔔',
                                  style: GoogleFonts.sora(
                                      fontSize: 11,
                                      color: kOrange,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(
                                widget.trip.vehicle.toUpperCase(),
                                style: GoogleFonts.sora(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: kOrange),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Trip ${widget.trip.tripCode} • ${widget.trip.riderName}',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: kMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (widget.trip.isNonAcRequest) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: kOrangeLight,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                        color: kOrange.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    'Non-AC request',
                                    style: GoogleFonts.sora(
                                      fontSize: 10,
                                      color: kOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CustomPaint(
                            painter: _CountdownPainter(progress: _progress),
                            child: Center(
                              child: Text('$_timer',
                                  style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: kOrange)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: kGray,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: kSuccess,
                                          boxShadow: [
                                            BoxShadow(
                                                color: kSuccess, blurRadius: 6)
                                          ])),
                                  Container(
                                      width: 1.5, height: 26, color: kGray2),
                                  Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                          color: kOrange,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          boxShadow: [
                                            BoxShadow(
                                                color: kOrange, blurRadius: 6)
                                          ])),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PICKUP',
                                        style: GoogleFonts.sora(
                                            fontSize: 10,
                                            color: kMuted,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 3),
                                    Text(widget.trip.pickup,
                                        style: GoogleFonts.sora(
                                            fontSize: 13,
                                            color: kDark,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.trip.pickupDistanceKm > 0
                                          ? '${widget.trip.pickupDistanceKm.toStringAsFixed(1)} km to pickup'
                                          : 'Driver distance not available',
                                      style: GoogleFonts.sora(
                                        fontSize: 11,
                                        color: kOrange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text('DROP-OFF',
                                        style: GoogleFonts.sora(
                                            fontSize: 10,
                                            color: kMuted,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 3),
                                    Text(widget.trip.drop,
                                        style: GoogleFonts.sora(
                                            fontSize: 13,
                                            color: kDark,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${widget.trip.tripDistanceKm.toStringAsFixed(1)} km trip',
                                      style: GoogleFonts.sora(
                                        fontSize: 11,
                                        color: kSuccess,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _MetaChip(
                                  icon: '📍',
                                  value: '${widget.trip.distance} km'),
                              _MetaChip(
                                  icon: '⏱️',
                                  value: '${widget.trip.duration} min'),
                              _MetaChip(icon: '💵', value: widget.trip.payment),
                              _MetaChip(
                                  icon: '⭐', value: widget.trip.riderRating),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.trip.message.isNotEmpty ||
                        widget.trip.bonusAmount > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kGray2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.trip.message.isNotEmpty) ...[
                              Text(
                                widget.trip.message,
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: kDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (widget.trip.bonusAmount > 0)
                              Text(
                                'Bonus included: +₹${widget.trip.bonusAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: kSuccess,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: kOrangeLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: kOrange.withOpacity(0.2), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('💰 Your earnings',
                              style: GoogleFonts.sora(
                                  fontSize: 13,
                                  color: kOrange,
                                  fontWeight: FontWeight.w600)),
                          Text('₹${widget.trip.driverEarnings}',
                              style: GoogleFonts.sora(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: kOrange)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineBtn(
                              label: 'Decline', onTap: widget.onDecline),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _GradientBtn(
                              label: 'Accept Ride ✓', onTap: widget.onAccept),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  final double progress;
  const _CountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(center, radius, Paint()..color = kOrangeLight);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = kGray2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = kOrange
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_CountdownPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════
//  ACTIVE TRIP PANEL
// ══════════════════════════════════════════════════════════════
class ActiveTripPanel extends StatelessWidget {
  final TripData trip;
  final Function(String) onAction;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final Function(double, double) onNavigate;
  const ActiveTripPanel(
      {super.key,
      required this.trip,
      required this.onAction,
      required this.onCall,
      required this.onChat,
      required this.onNavigate});

  static const _steps = [
    ('accepted', 'Head to Pickup', 'arrived', "I've Arrived", kInfo, '🚗'),
    (
      'arrived',
      'Verify rider OTP',
      'start',
      'Verify OTP & Start',
      kOrange,
      '🔐'
    ),
    (
      'started',
      'Trip in Progress',
      'complete',
      'Complete Trip',
      kSuccess,
      '🛣️'
    ),
    (
      'driver_assigned',
      'Head to Pickup',
      'arrived',
      "I've Arrived",
      kInfo,
      '🚗'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final status = _normalizeTripStatus(trip.status);
    final cur =
        _steps.firstWhere((s) => s.$1 == status, orElse: () => _steps[0]);
    final color = cur.$5 as Color;
    final icon = cur.$6;
    final label = cur.$2;
    final btn = cur.$4;
    final action = cur.$3;
    final canCancel = status == 'accepted' ||
        status == 'driver_assigned' ||
        status == 'arrived';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 40, offset: Offset(0, -8))
          ],
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: kGray2,
                        borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Text(icon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ACTIVE TRIP',
                                    style: GoogleFonts.sora(
                                        fontSize: 10,
                                        color: color,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8)),
                                Text(label,
                                    style: GoogleFonts.sora(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kDark)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Your earnings',
                                  style: GoogleFonts.sora(fontSize: 10, color: kMuted)),
                              Text('₹${trip.driverEarnings}',
                                  style: GoogleFonts.sora(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: kOrange)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: kGray, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: trip.riderPhotoUrl.isEmpty
                                  ? const LinearGradient(
                                      colors: [kOrange, kOrangeDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight)
                                  : null,
                              image: trip.riderPhotoUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(trip.riderPhotoUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: trip.riderPhotoUrl.isEmpty
                                ? Center(
                                    child: Text(
                                        trip.riderName.isNotEmpty ? trip.riderName[0] : 'R',
                                        style: GoogleFonts.sora(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: kWhite)))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.riderName,
                                    style: GoogleFonts.sora(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: kDark)),
                                Text('⭐ ${trip.riderRating} · ${trip.vehicle}',
                                    style:
                                        GoogleFonts.sora(fontSize: 12, color: kMuted)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _CircleBtn(
                                  icon: '🧭',
                                  bg: kOrange.withOpacity(0.15),
                                  border: kOrange.withOpacity(0.27),
                                  onTap: () {
                                    final status = _normalizeTripStatus(trip.status);
                                    double? lat;
                                    double? lng;
                                    if (status == 'started') {
                                      lat = trip.dropLat;
                                      lng = trip.dropLng;
                                    } else {
                                      lat = trip.pickupLat;
                                      lng = trip.pickupLng;
                                    }
                                    if (lat != null && lng != null) {
                                      onNavigate(lat, lng);
                                    }
                                  }),
                              const SizedBox(width: 8),
                              _CircleBtn(
                                  icon: '📞',
                                  bg: kSuccess.withOpacity(0.15),
                                  border: kSuccess.withOpacity(0.27),
                                  onTap: onCall),
                              const SizedBox(width: 8),
                              _CircleBtn(
                                  icon: '💬',
                                  bg: kGray2,
                                  border: kGray2,
                                  onTap: onChat),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: kGray, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: kSuccess,
                                        boxShadow: [
                                          BoxShadow(color: kSuccess, blurRadius: 5)
                                        ])),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(trip.pickup,
                                      style: GoogleFonts.sora(
                                          fontSize: 13, color: kDark))),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 3),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                  width: 1.5,
                                  height: 12,
                                  color: const Color(0xFFCCCCCC)),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: kOrange,
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(color: kOrange, blurRadius: 5)
                                        ])),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(trip.drop,
                                      style: GoogleFonts.sora(
                                          fontSize: 13, color: kDark))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => onAction(action),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: color.withOpacity(0.27),
                        ),
                        child: Text('$btn →',
                            style: GoogleFonts.sora(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (canCancel) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => onAction('cancel'),
                          icon: const Text('✕', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          label: Text('Cancel Ride',
                              style: GoogleFonts.sora(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kError,
                            side: const BorderSide(color: kError, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Cash + SOS buttons
                    Row(children: [
                      if (status == 'completed')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => onAction('cash'),
                            icon: const Text('💵', style: TextStyle(fontSize: 18)),
                            label: const Text('Cash Collected'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      if (status == 'completed') const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => onAction('sos'),
                          icon: const Text('🆘', style: TextStyle(fontSize: 18)),
                          label: const Text('SOS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverTripReviewScreen extends StatefulWidget {
  final TripData trip;
  const DriverTripReviewScreen({super.key, required this.trip});

  @override
  State<DriverTripReviewScreen> createState() => _DriverTripReviewScreenState();
}

class _DriverTripReviewScreenState extends State<DriverTripReviewScreen> {
  static const _quickComments = [
    'Polite rider',
    'Easy pickup',
    'Smooth trip',
    'Good communication',
    'Paid on time',
  ];

  final _commentController = TextEditingController();
  int _score = 5;
  bool _submitting = false;

  Future<void> _submitReview() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final res = await ApiService.rateDriver(
      widget.trip.id,
      _score,
      _commentController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true || res['status'] == 400) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Review submitted! Thank you.'),
        backgroundColor: kSuccess,
      ));
      _goHome();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['error'] ?? 'Something went wrong.'),
      backgroundColor: kError,
    ));
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Review Rider',
            style: GoogleFonts.sora(
                color: kDark, fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _goHome,
            child: Text(
              'Skip',
              style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kMuted),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: kOrangeLight,
                  shape: BoxShape.circle,
                  image: widget.trip.riderPhotoUrl.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(widget.trip.riderPhotoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: widget.trip.riderPhotoUrl.isEmpty
                    ? const Icon(Icons.person_rounded,
                        color: kOrange, size: 42)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(widget.trip.riderName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                      fontSize: 22, fontWeight: FontWeight.w900, color: kDark)),
              const SizedBox(height: 6),
              Text('Trip ${widget.trip.tripCode} completed',
                  style: GoogleFonts.sora(fontSize: 13, color: kMuted)),
              const SizedBox(height: 28),
              Text('How was this rider?',
                  style: GoogleFonts.sora(
                      fontSize: 16, fontWeight: FontWeight.w800, color: kDark)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _score = i + 1),
                    icon: Icon(
                      i < _score
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: kOrange,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Quick review',
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kDark)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickComments.map((text) {
                  final selected = _commentController.text == text;
                  return ChoiceChip(
                    label: Text(text),
                    selected: selected,
                    selectedColor: kOrangeLight,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() {
                              _commentController.text = text;
                            }),
                    labelStyle: GoogleFonts.sora(
                      fontSize: 12,
                      color: selected ? kOrange : kDark,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    side: BorderSide(
                        color: selected ? kOrange : kGray2, width: 1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write your own comment',
                  filled: true,
                  fillColor: kGray,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_submitting ? 'Submitting...' : 'Submit Review',
                      style: GoogleFonts.sora(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverTripChatScreen extends StatefulWidget {
  final int tripId;
  final String riderName;
  final VoidCallback onClose;

  const DriverTripChatScreen({
    super.key,
    required this.tripId,
    required this.riderName,
    required this.onClose,
  });

  @override
  State<DriverTripChatScreen> createState() => _DriverTripChatScreenState();
}

class _DriverTripChatScreenState extends State<DriverTripChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _quickMsgs = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      final msgs = await ApiService.getChatMessages(widget.tripId);
      final quick = await ApiService.getQuickMessages();
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
            msgs['data']?['messages'] ?? msgs['messages'] ?? const []);
        _quickMsgs = List<Map<String, dynamic>>.from(quick['data']
                ?['quick_messages'] ??
            quick['quick_messages'] ??
            const []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendMessage(String text,
      {String type = 'text', String? quickKey}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.sendChatMessage(
        widget.tripId,
        type,
        text,
        quickKey,
      );
      if (res['success'] == true) {
        _msgCtrl.clear();
        await _loadData(silent: true);
        if (_scrollCtrl.hasClients) {
          await Future.delayed(const Duration(milliseconds: 150));
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Failed to send message')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = AuthService.userId;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Chat with ${widget.riderName.isNotEmpty ? widget.riderName : "Rider"}',
          style: GoogleFonts.sora(
            color: kDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kDark),
          onPressed: widget.onClose,
        ),
      ),
      body: Column(
        children: [
          if (_quickMsgs.isNotEmpty)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickMsgs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final q = _quickMsgs[i];
                  final String lang = AuthService.language;
                  final String label;
                  if (lang == 'bn') {
                    label = q['text_bn'] ?? q['text_en'] ?? '';
                  } else if (lang == 'hi') {
                    label = q['text_hi'] ?? q['text_en'] ?? '';
                  } else {
                    label = q['text_en'] ?? q['text_bn'] ?? '';
                  }
                  return GestureDetector(
                    onTap: () => _sendMessage(
                      label,
                      type: 'quick',
                      quickKey: q['key'],
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: kOrangeLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: kOrange.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          color: kOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kOrange),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final m = _messages[i];
                      final isMe = (m['sender_id'] as num?)?.toInt() == myId;
                      final text = m['message_text']?.toString() ?? '';
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: isMe ? kOrange : kGray,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            text,
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              color: isMe ? Colors.white : kDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: kGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending
                      ? null
                      : () {
                          final text = _msgCtrl.text.trim();
                          if (text.isNotEmpty) {
                            _sendMessage(text);
                          }
                        },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _sending ? kMuted : kOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EARNINGS SCREEN
// ══════════════════════════════════════════════════════════════
class EarningsScreen extends StatelessWidget {
  final EarningsData earnings;
  final VoidCallback onClose;
  final VoidCallback onWithdrawPressed;
  const EarningsScreen({
    super.key,
    required this.earnings,
    required this.onClose,
    required this.onWithdrawPressed,
  });

  static const _periods = [
    ('Today', '☀️', 3),
    ('This Week', '📅', 18),
    ('This Month', '🗓️', 74),
    ('All Time', '🏆', 312),
  ];

  @override
  Widget build(BuildContext context) {
    final amts = [
      earnings.today,
      earnings.week,
      earnings.month,
      earnings.allTime
    ];

    return Container(
      color: kWhite,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kGray2))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: kGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kGray2)),
                      child: const Center(
                          child: Text('←',
                              style: TextStyle(fontSize: 18, color: kDark)))),
                ),
                const SizedBox(width: 14),
                Text('My Earnings',
                    style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kDark)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [kOrange, kOrangeDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: kOrange.withOpacity(0.27),
                          blurRadius: 40,
                          offset: const Offset(0, 12))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Balance',
                          style: GoogleFonts.sora(
                              fontSize: 12, color: const Color(0xBFFFFFFF))),
                      const SizedBox(height: 4),
                      Text('₹${earnings.wallet}',
                          style: GoogleFonts.sora(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: kWhite)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _WalletStat(
                                    label: 'Today',
                                    value: '₹${earnings.today}'),
                                const SizedBox(width: 20),
                                _WalletStat(
                                    label: 'This Week',
                                    value: '₹${earnings.week}'),
                                const SizedBox(width: 20),
                                _WalletStat(
                                    label: 'Trips', value: '${earnings.trips}'),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: onWithdrawPressed,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kWhite,
                              side: const BorderSide(color: Color(0x4DFFFFFF)),
                              backgroundColor: Colors.white.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            child: Text('Withdraw',
                                style: GoogleFonts.sora(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (int i = 0; i < _periods.length; i++) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGray2),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: kOrangeLight,
                                borderRadius: BorderRadius.circular(12)),
                            child: Center(
                                child: Text(_periods[i].$2,
                                    style: const TextStyle(fontSize: 20)))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_periods[i].$1,
                                  style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kDark)),
                              Text('${_periods[i].$3} trips',
                                  style: GoogleFonts.sora(
                                      fontSize: 12, color: kMuted)),
                            ],
                          ),
                        ),
                        Text('₹${amts[i]}',
                            style: GoogleFonts.sora(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: kOrange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SMALL REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════
class _MetaChip extends StatelessWidget {
  final String icon, value;
  const _MetaChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 3),
              Text(value,
                  style: GoogleFonts.sora(
                      fontSize: 10, color: kDark, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
}

class _CircleBtn extends StatelessWidget {
  final String icon;
  final Color bg, border;
  final VoidCallback? onTap;
  const _CircleBtn(
      {required this.icon, required this.bg, required this.border, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(color: border, width: 1.5)),
          child:
              Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
        ),
      );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: kGray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGray2)),
          child: Center(
              child: Text(label,
                  style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kMuted))),
        ),
      );
}

class _GradientBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [kOrange, kOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: kOrange.withOpacity(0.27),
                  blurRadius: 24,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Center(
              child: Text(label,
                  style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kWhite))),
        ),
      );
}

class _WalletStat extends StatelessWidget {
  final String label, value;
  const _WalletStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.sora(
                  fontSize: 10, color: kWhite.withOpacity(0.65))),
          Text(value,
              style: GoogleFonts.sora(
                  fontSize: 15, fontWeight: FontWeight.w800, color: kWhite)),
        ],
      );
}

// ── Pulsing online dot ──
class _OnlineDot extends StatefulWidget {
  final bool isOnline;
  const _OnlineDot({required this.isOnline});
  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _anim = Tween(begin: 1.0, end: 0.4).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline)
      return Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFFCCCCCC)));
    return FadeTransition(
      opacity: _anim,
      child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSuccess,
              boxShadow: [BoxShadow(color: kSuccess, blurRadius: 6)])),
    );
  }
}

// ── Toggle button ──
class _ToggleButton extends StatelessWidget {
  final bool isOnline, toggling;
  final AnimationController spinCtrl;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.isOnline,
      required this.toggling,
      required this.spinCtrl,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggling ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isOnline
              ? const LinearGradient(
                  colors: [Color(0xFFF0FFF4), Color(0xFFE8F5E9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : const LinearGradient(
                  colors: [kOrange, kOrangeDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: isOnline
              ? Border.all(color: kSuccess.withOpacity(0.27), width: 2)
              : null,
          boxShadow: isOnline
              ? [
                  BoxShadow(
                      color: kSuccess.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4))
                ]
              : [
                  BoxShadow(
                      color: kOrange.withOpacity(0.27),
                      blurRadius: 30,
                      offset: const Offset(0, 8))
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (toggling)
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOnline ? kSuccess : kWhite,
                  ),
                ),
              )
            else ...[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? kSuccess.withOpacity(0.12)
                      : Colors.white.withOpacity(0.18),
                  border: Border.all(
                      color: isOnline
                          ? kSuccess.withOpacity(0.4)
                          : Colors.white.withOpacity(0.4),
                      width: 2),
                ),
                child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isOnline ? 'Go Offline' : 'Go Online',
                      style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isOnline ? kSuccess : kWhite)),
                  Text(isOnline ? 'Stop accepting rides' : 'Start earning now',
                      style: GoogleFonts.sora(
                          fontSize: 12,
                          color: isOnline
                              ? kSuccess.withOpacity(0.67)
                              : kWhite.withOpacity(0.75))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Quick action button ──
class _QuickAction extends StatelessWidget {
  final String icon, label;
  final bool danger;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.danger,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColor = danger ? const Color(0xFFFFF0F0) : kOrangeLight;
    final accentColor = danger ? const Color(0xFFE53935) : kOrange;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: accentColor.withOpacity(0.13),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
                border: Border.all(
                    color: accentColor.withOpacity(0.13), width: 1.5),
              ),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.sora(
                    fontSize: 11, fontWeight: FontWeight.w600, color: kDark),
                textAlign: TextAlign.center,
                maxLines: 1),
          ],
        ),
      ),
    );
  }
}

// ── Today stat cell ──
class _StatCell extends StatelessWidget {
  final String label, value;
  final bool showDivider, last;
  const _StatCell(
      {required this.label,
      required this.value,
      this.showDivider = false,
      this.last = false});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          decoration: showDivider && !last
              ? const BoxDecoration(
                  border: Border(left: BorderSide(color: kGray2)))
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: GoogleFonts.sora(
                      fontSize: 15, fontWeight: FontWeight.w800, color: kDark)),
              const SizedBox(height: 2),
              Text(label,
                  style: GoogleFonts.sora(
                      fontSize: 9,
                      color: kMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  MAIN DRIVER HOME
// ══════════════════════════════════════════════════════════════
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isOnline = AuthService.isOnline;
  bool _toggling = false;
  bool _isChatOpen = false;
  TripData? _incomingTrip;
  TripData? _activeTrip;
  DateTime? _tripStartedAt;
  MapplsMapController? _mapController;
  Symbol? _pickupSymbol;
  Symbol? _dropSymbol;
  final Set<String> _registeredIcons = {};
  int _navIndex = 0;
  final Offset _driverPos = const Offset(0.5, 0.42);
  String _greeting = 'Good morning';

  // Backend vars
  double _currentLat = 0;
  double _currentLng = 0;
  bool _loadingActive = false;
  Map<String, dynamic>? _earningsRaw;
  Timer? _tripPollingTimer;

  late AnimationController _spinCtrl;
  bool _isAppBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen for events from the overlay window isolate
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        final action = event['action'];
        final tripId = event['tripId'];
        if (action == 'accept' && tripId != null) {
          _acceptTripById(tripId);
        } else if (action == 'decline' && tripId != null) {
          _handleDecline();
        }
      }
    });

    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat();
    final h = DateTime.now().hour;
    if (h < 12)
      _greeting = 'Good morning';
    else if (h < 17)
      _greeting = 'Good afternoon';
    else
      _greeting = 'Good evening';

    _getLocation();
    _loadEarnings();
    _checkActiveTrip();
    _refreshProfileStatus();
    if (_isOnline) {
      _connectDriverSocket();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isAppBackgrounded = true;
    } else if (state == AppLifecycleState.resumed) {
      _isAppBackgrounded = false;
      // Close overlay window when app returns to foreground
      FlutterOverlayWindow.closeOverlay();
      _refreshProfileStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spinCtrl.dispose();
    _tripPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
      await AuthService.saveLastLocation(_currentLat, _currentLng);
      await ApiService.updateLocation(_currentLat, _currentLng);
      if (_isOnline) {
        _connectDriverSocket();
      }
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen((pos) async {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        await AuthService.saveLastLocation(_currentLat, _currentLng);
        if (mounted) {
          setState(() {});
        }
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_currentLat, _currentLng)));
        }
        if (_isOnline) {
          await ApiService.updateLocation(_currentLat, _currentLng);
          _connectDriverSocket();
        }
        if (_activeTrip != null) {
          _drawTripRoute();
        }
      });
    } catch (_) {}
  }

  Future<void> _connectDriverSocket() async {
    DriverSocketService.onMessage = (data) {
      debugPrint('Socket message: $data');

      if (data['type'] == 'kicked') {
        DriverSocketService.disconnect();
        AuthService.logout(
          forced: true,
          message: data['message'] ?? 'Your account was logged in on another device.',
        );
        return;
      }

      if (data['type'] == 'new_trip') {
        final tripData = data['data'];

        RideAlertService.startAlert();

        if (mounted) {
          setState(() {
            _incomingTrip = _mapToTripData(tripData);
          });
        }

        _triggerOverlay(tripData);
      }

      if (data['type'] == 'trip_taken') {
        if (mounted) {
          setState(() {
            _incomingTrip = null;
          });
        }
        FlutterOverlayWindow.closeOverlay();

        _showSnack(
          'Trip already taken',
          isError: true,
        );
      }

      if (data['type'] == 'chat_message') {
        if (_activeTrip != null && !_isChatOpen) {
          _openRiderChat();
        }
      }

      if (data['type'] == 'trip_cancelled') {
        _clearRoute();
        if (_isChatOpen) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        if (mounted) {
          setState(() {
            _activeTrip = null;
          });
        }
        final cancelledBy = data['cancelled_by']?.toString();
        if (cancelledBy != 'driver') {
          _showSnack(
            'Rider cancelled this ride for: ${data['reason'] ?? 'No reason given'}',
            isError: true,
          );
        }
      }

      if (data['type'] == 'trip_completed') {
        _processTripCompletion(data);
      }
    };

    if (DriverSocketService.isConnected) return;
    try {
      await DriverSocketService.connect(
        AuthService.driverId,
        AuthService.token,
      );
    } catch (e) {
      debugPrint('Driver socket connect error: $e');
    }
  }

  Future<void> _handleToggle() async {
    try {
      if (mounted) {
        setState(() => _toggling = true);
      }

      final res = await ApiService.toggleOnline();

      if (res['success']) {
        final online = res['data']['is_online'] == true;
        await AuthService.setIsOnline(online);

        if (mounted) {
          setState(() => _isOnline = online);
        }

        _showSnack(
          res['data']['message'],
          isError: false,
        );

        if (online) {
          if (Platform.isAndroid) {
            try {
              await Permission.notification.request();
              final isGranted = await FlutterOverlayWindow.isPermissionGranted();
              if (!isGranted) {
                // Request permission without awaiting to avoid blocking/suspending the online toggle execution flow when settings open
                FlutterOverlayWindow.requestPermission();
              }
            } catch (e) {
              debugPrint('Error checking/requesting permissions: $e');
            }
          }
          await FlutterBackgroundService().startService();

          await ApiService.updateLocation(
            _currentLat,
            _currentLng,
          );

          await _connectDriverSocket();
        } else {
          await RideAlertService.stopAlert();
          DriverSocketService.disconnect();
          FlutterBackgroundService().invoke("stopService");
          FlutterOverlayWindow.closeOverlay();

          if (mounted) {
            setState(() {
              _incomingTrip = null;
              _activeTrip = null;
            });
          }
        }
      } else {
        _showSnack(
          res['error'] ?? 'Toggle failed',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Toggle error: $e');

      _showSnack(
        'Something went wrong',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  Future<void> _loadAvailableTrips() async {
    if (!_isOnline || _activeTrip != null || _incomingTrip != null) return;
    final res = await ApiService.getAvailableTrips();
    if (res['success']) {
      final trips = res['data']['trips'] as List?;
      if (trips != null && trips.isNotEmpty && mounted) {
        setState(() {
          _incomingTrip = _mapToTripData(trips.first);
        });
      }
    }
  }

  Future<void> _checkActiveTrip() async {
    setState(() => _loadingActive = true);
    final res = await ApiService.getDriverActiveTrip();
    if (res['success'] && res['data']['active_trip'] != null) {
      await AuthService.setIsOnline(true);
      if (mounted) {
        setState(() {
          _activeTrip = _mapToTripData(res['data']['active_trip']);
          _isOnline = true;
        });
        _connectDriverSocket();
      }
    } else {
      if (mounted) setState(() => _activeTrip = null);
      if (_isOnline) {
        _connectDriverSocket();
      }
    }
    if (mounted) setState(() => _loadingActive = false);
  }

  Future<void> _handleAccept() async {
    if (_incomingTrip == null) return;
    final res = await ApiService.acceptTrip(_incomingTrip!.id);
    if (res['success']) {
      _showSnack('Trip accepted! Head to pickup. 📍', isError: false);
      await RideAlertService.stopAlert();
      setState(() => _incomingTrip = null);
      await _checkActiveTrip();
      if (_activeTrip != null && _activeTrip!.pickupLat != null && _activeTrip!.pickupLng != null) {
        _openNavigation(_activeTrip!.pickupLat!, _activeTrip!.pickupLng!);
      }
    } else {
      _showSnack(res['error'], isError: true);
      await RideAlertService.stopAlert();
      setState(() => _incomingTrip = null);
    }
  }

  Future<void> _handleDecline() async {
    if (_incomingTrip != null) {
      try {
        await ApiService.rejectTrip(_incomingTrip!.id);
      } catch (e) {
        debugPrint('Reject trip error: $e');
      }
    }
    await RideAlertService.stopAlert();
    setState(() => _incomingTrip = null);
  }

  Future<void> _acceptTripById(int tripId) async {
    final res = await ApiService.acceptTrip(tripId);
    if (res['success']) {
      _showSnack('Trip accepted! Head to pickup. 📍', isError: false);
      await RideAlertService.stopAlert();
      if (mounted) {
        setState(() {
          _incomingTrip = null;
        });
      }
      await _checkActiveTrip();
      if (_activeTrip != null && _activeTrip!.pickupLat != null && _activeTrip!.pickupLng != null) {
        _openNavigation(_activeTrip!.pickupLat!, _activeTrip!.pickupLng!);
      }
    } else {
      _showSnack(res['error'] ?? 'Accept failed', isError: true);
      await RideAlertService.stopAlert();
      if (mounted) {
        setState(() {
          _incomingTrip = null;
        });
      }
    }
  }

  Future<void> _triggerOverlay(dynamic rawData) async {
    if (!_isAppBackgrounded) return;

    final isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) return;

    final trip = _mapToTripData(rawData);
    final payload = {
      'id': trip.id,
      'fare': trip.fare,
      'pickup': trip.pickup,
      'drop': trip.drop,
      'distance': trip.distance,
      'pickupDistanceKm': trip.pickupDistanceKm,
      'vehicle': trip.vehicle,
      'payment': trip.payment,
      'secondsLeft': 25,
    };

    await FlutterOverlayWindow.showOverlay(
      height: 380,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.topCenter,
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: "New Ride Request",
      overlayContent: "Accept the booking request",
      enableDrag: true,
    );

    // Share data to overlay isolate
    await Future.delayed(const Duration(milliseconds: 150));
    await FlutterOverlayWindow.shareData(payload);
    await Future.delayed(const Duration(milliseconds: 150));
    await FlutterOverlayWindow.shareData(payload);
  }

  Future<void> _callRider() async {
    final trip = _activeTrip;
    if (trip == null) return;

    final phone = trip.riderPhone.trim();
    if (phone.isEmpty) {
      _showSnack('Rider phone number is not available.', isError: true);
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open phone dialer', isError: true);
    }
  }

  void _openRiderChat() {
    final trip = _activeTrip;
    if (trip == null) return;
    if (_isChatOpen || DriverSocketService.isChatOpen) return;

    setState(() {
      _isChatOpen = true;
      DriverSocketService.isChatOpen = true;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverTripChatScreen(
          tripId: trip.id,
          riderName: trip.riderName,
          onClose: () {
            Navigator.pop(context);
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isChatOpen = false;
          DriverSocketService.isChatOpen = false;
        });
      }
    });
  }

  Future<void> _openNavigation(double lat, double lng) async {
    final googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    final appleMapsUrl = Uri.parse("http://maps.apple.com/?daddr=$lat,$lng");
    
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalNonBrowserApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        final webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          _showSnack('Could not open maps application', isError: true);
        }
      }
    } catch (e) {
      try {
        final webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (innerError) {
        _showSnack('Error launching navigation: $innerError', isError: true);
      }
    }
  }

  Future<String?> _askTripOtp() async {
    final controller = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Verify Rider OTP',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask the rider for the 4 digit trip OTP before starting the ride.',
              style: GoogleFonts.sora(fontSize: 13, color: kMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.sora(
                  fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                hintText: '0000',
                hintStyle: GoogleFonts.sora(
                    color: kMuted.withOpacity(0.35), letterSpacing: 8),
                filled: true,
                fillColor: kGray,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kOrange, width: 2)),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.sora(color: kMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length == 4) {
                Navigator.pop(dialogContext, value);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kOrange,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Start Trip',
                style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    controller.dispose();
    return otp;
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final isEnabled = controller.text.trim().length >= 4;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Cancel Ride',
                style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 3,
              onChanged: (val) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Reason for cancellation (required)',
                filled: true,
                fillColor: kGray,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Back', style: GoogleFonts.sora(color: kMuted)),
              ),
              ElevatedButton(
                onPressed: isEnabled
                    ? () {
                        final value = controller.text.trim();
                        Navigator.pop(dialogContext, value);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kError,
                  foregroundColor: kWhite,
                  disabledBackgroundColor: kError.withOpacity(0.3),
                  disabledForegroundColor: kWhite.withOpacity(0.5),
                ),
                child: Text('Cancel Ride',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<bool> _confirmCashCollected(TripData trip) async {
    final riderPayable = trip.actualFare;
    final promoDiscount = trip.promoDiscount;
    final companySettlement = promoDiscount;
    final driverEarnings = trip.driverEarnings.toDouble();
    final bonusAmount = trip.bonusAmount;
    final totalDriverSettlement = driverEarnings + bonusAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Cash Receipt',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please collect cash from the rider and verify details below:',
                style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: kOrangeLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kOrange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('COLLECT FROM RIDER',
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          color: kOrangeDark,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('₹${riderPayable.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(
                          fontSize: 32,
                          color: kOrange,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow('Estimated Base Fare', '₹${trip.totalFare.toStringAsFixed(0)}'),
            if (promoDiscount > 0)
              _buildDialogBreakdownRow(
                'Coupon Discount (${trip.promoCode ?? "Applied"})', 
                '-₹${promoDiscount.toStringAsFixed(0)}',
                valueColor: Colors.green[700],
              ),
            if (companySettlement > 0) ...[
              const SizedBox(height: 4),
              _buildDialogBreakdownRow(
                'Company Pays Driver', 
                '+₹${companySettlement.toStringAsFixed(0)}',
                valueColor: kOrangeDark,
                isBold: true,
              ),
            ],
            if (bonusAmount > 0)
              _buildDialogBreakdownRow('Trip Bonus added', '+₹${bonusAmount.toStringAsFixed(0)}', valueColor: Colors.green[700]),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow(
              'Your Total Earnings', 
              '₹${totalDriverSettlement.toStringAsFixed(0)}',
              isBold: true,
              fontSize: 14,
              valueColor: kDark,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.sora(color: kMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSuccess,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text('Cash Collected',
                style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _buildDialogBreakdownRow(String label, String value, {Color? valueColor, bool isBold = false, double fontSize = 12}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.sora(fontSize: fontSize, color: isBold ? kDark : kMuted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: GoogleFonts.sora(fontSize: fontSize, color: valueColor ?? kDark, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _processTripCompletion(Map<String, dynamic> payload) async {
    final tripId = payload['trip_id'] as int? ?? 0;
    
    // Safety check to ensure we only process if this was our active trip
    if (_activeTrip == null || _activeTrip!.id != tripId) return;
    
    final paymentMethod = payload['payment_method']?.toString().toLowerCase() ?? 'cash';
    final isCash = paymentMethod.contains('cash');
    
    bool confirmed = true;
    if (isCash) {
      confirmed = await _confirmCashCollectedPayload(payload);
      if (confirmed) {
        final cashRes = await ApiService.markCashCollected(tripId);
        if (cashRes['success'] == true) {
          final Map<String, dynamic> data = Map<String, dynamic>.from({
            ...payload,
            ...?cashRes['data'],
            'cash_collected': payload['cash_to_collect'] ?? payload['net_rider_fare'] ?? cashRes['amount'],
            'promo_discount': payload['promo_discount'],
            'commission_deducted': payload['commission'],
            'company_pays_you': payload['company_pays_driver'],
            'your_net_earnings': payload['your_earnings'],
          });
          await _showCashCollectedBreakdown(data);
        } else {
          _showSnack(cashRes['error'] ?? 'Cash confirmation failed', isError: true);
        }
      }
    } else {
      await _showWalletTripSummary(payload);
    }
    
    _clearRoute();
    _showSnack('Trip completed! 🎉', isError: false);
    
    final trip = _activeTrip!;
    await _askDriverReview(trip);
    if (mounted) {
      setState(() {
        _activeTrip = null;
      });
    }
    _loadEarnings();
  }

  Future<bool> _confirmCashCollectedPayload(Map<String, dynamic> payload) async {
    final double actualFare = double.tryParse((payload['actual_fare'] ?? 0).toString()) ?? 0.0;
    final double promoDiscount = double.tryParse((payload['promo_discount'] ?? 0).toString()) ?? 0.0;
    final String promoCode = payload['promo_code']?.toString() ?? '';
    final double totalDiscount = double.tryParse((payload['total_discount'] ?? 0).toString()) ?? 0.0;
    final double cashToCollect = double.tryParse((payload['cash_to_collect'] ?? 0).toString()) ?? 0.0;
    final double companyPaysDriver = double.tryParse((payload['company_pays_driver'] ?? 0).toString()) ?? 0.0;
    final double yourEarnings = double.tryParse((payload['your_earnings'] ?? payload['driver_earnings'] ?? 0).toString()) ?? 0.0;
    final double commission = double.tryParse((payload['commission'] ?? payload['platform_fee'] ?? 0).toString()) ?? 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm Cash Receipt',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please collect cash from the rider and verify details below:',
                style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: kOrangeLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kOrange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('COLLECT FROM RIDER',
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          color: kOrangeDark,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('₹${cashToCollect.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(
                          fontSize: 32,
                          color: kOrange,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow('Trip Fare', '₹${actualFare.toStringAsFixed(0)}'),
            if (promoDiscount > 0)
              _buildDialogBreakdownRow(
                'Promo Discount (${promoCode.isNotEmpty ? promoCode : "Applied"})', 
                '-₹${promoDiscount.toStringAsFixed(0)}',
                valueColor: Colors.green[700],
              ),
            if (totalDiscount > 0)
              _buildDialogBreakdownRow(
                'Total Discount', 
                '-₹${totalDiscount.toStringAsFixed(0)}',
                valueColor: Colors.green[700],
              ),
            if (commission > 0)
              _buildDialogBreakdownRow(
                'Commission to Company', 
                '-₹${commission.toStringAsFixed(0)}',
                valueColor: Colors.red[700],
              ),
            if (companyPaysDriver > 0)
              _buildDialogBreakdownRow(
                'Company Pays You', 
                '+₹${companyPaysDriver.toStringAsFixed(0)}',
                valueColor: kOrangeDark,
                isBold: true,
              ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow(
              'Your Total Earnings', 
              '₹${yourEarnings.toStringAsFixed(0)}',
              isBold: true,
              valueColor: kDark,
            ),
            if (commission > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Note: Since you take cash, the company commission of ₹${commission.toStringAsFixed(0)} will be deducted from your wallet balance.',
                style: GoogleFonts.sora(fontSize: 10, color: Colors.red[800], fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text('Confirm Cash Received',
                      style: GoogleFonts.sora(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showWalletTripSummary(Map<String, dynamic> payload) async {
    final double actualFare = double.tryParse((payload['actual_fare'] ?? 0).toString()) ?? 0.0;
    final double promoDiscount = double.tryParse((payload['promo_discount'] ?? 0).toString()) ?? 0.0;
    final String promoCode = payload['promo_code']?.toString() ?? '';
    final double totalDiscount = double.tryParse((payload['total_discount'] ?? 0).toString()) ?? 0.0;
    final double netRiderFare = double.tryParse((payload['net_rider_fare'] ?? 0).toString()) ?? 0.0;
    final double yourEarnings = double.tryParse((payload['your_earnings'] ?? payload['driver_earnings'] ?? 0).toString()) ?? 0.0;
    final double commission = double.tryParse((payload['commission'] ?? payload['platform_fee'] ?? 0).toString()) ?? 0.0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Trip Completed',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trip completed! Rider paid via wallet:',
                style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('RIDER PAID VIA WALLET',
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('₹${netRiderFare.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(
                          fontSize: 32,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow('Trip Fare', '₹${actualFare.toStringAsFixed(0)}'),
            if (promoDiscount > 0)
              _buildDialogBreakdownRow(
                'Promo Discount (${promoCode.isNotEmpty ? promoCode : "Applied"})', 
                '-₹${promoDiscount.toStringAsFixed(0)}',
                valueColor: Colors.green[700],
              ),
            if (totalDiscount > 0)
              _buildDialogBreakdownRow(
                'Total Discount', 
                '-₹${totalDiscount.toStringAsFixed(0)}',
                valueColor: Colors.green[700],
              ),
            if (commission > 0)
              _buildDialogBreakdownRow(
                'Commission (Automatically Cut)', 
                '-₹${commission.toStringAsFixed(0)}',
                valueColor: Colors.red[700],
              ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow(
              'Your Total Earnings', 
              '₹${yourEarnings.toStringAsFixed(0)}',
              isBold: true,
              valueColor: kDark,
            ),
            if (commission > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Note: Since payment was online, the company commission of ₹${commission.toStringAsFixed(0)} was automatically cut from the fare.',
                style: GoogleFonts.sora(fontSize: 10, color: Colors.green[800], fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('OK',
                      style: GoogleFonts.sora(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCashCollectedBreakdown(Map<String, dynamic> data) async {
    final double cashCollected = double.tryParse((data['cash_collected'] ?? 0).toString()) ?? 0.0;
    final double promoDiscount = double.tryParse((data['promo_discount'] ?? 0).toString()) ?? 0.0;
    final double commissionDeducted = double.tryParse((data['commission_deducted'] ?? data['commission'] ?? data['platform_fee'] ?? 0).toString()) ?? 0.0;
    final double companyPaysYou = double.tryParse((data['company_pays_you'] ?? data['company_payable'] ?? 0).toString()) ?? 0.0;
    final double yourNetEarnings = double.tryParse((data['your_net_earnings'] ?? data['driver_earnings'] ?? 0).toString()) ?? 0.0;
    final double actualFare = double.tryParse((data['actual_fare'] ?? (cashCollected + promoDiscount)).toString()) ?? 0.0;
    final String promoCode = data['promo_code']?.toString() ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cash Collection Details',
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cash collection summary from backend:',
                style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: kSuccess.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kSuccess.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('CASH COLLECTED FROM RIDER',
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          color: kSuccess,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('₹${cashCollected.toStringAsFixed(0)}',
                      style: GoogleFonts.sora(
                          fontSize: 32,
                          color: kSuccess,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow('Trip Fare', '₹${actualFare.toStringAsFixed(0)}'),
            if (promoDiscount > 0)
              _buildDialogBreakdownRow(
                'Promo Discount (${promoCode.isNotEmpty ? promoCode : "Applied"})', 
                '-₹${promoDiscount.toStringAsFixed(0)}',
                valueColor: Colors.green[700],
              ),
            if (commissionDeducted > 0)
              _buildDialogBreakdownRow(
                'Commission Owed to Company', 
                '-₹${commissionDeducted.toStringAsFixed(0)}',
                valueColor: Colors.red[700],
              ),
            if (companyPaysYou > 0)
              _buildDialogBreakdownRow(
                'Company Pays You', 
                '+₹${companyPaysYou.toStringAsFixed(0)}',
                valueColor: kOrangeDark,
                isBold: true,
              ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogBreakdownRow(
              'Your Net Earnings', 
              '₹${yourNetEarnings.toStringAsFixed(0)}',
              isBold: true,
              valueColor: kDark,
            ),
            if (commissionDeducted > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Note: Since this is a cash trip, the company commission of ₹${commissionDeducted.toStringAsFixed(0)} will be deducted from your wallet balance.',
                style: GoogleFonts.sora(fontSize: 10, color: Colors.red[800], fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Done',
                      style: GoogleFonts.sora(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _askDriverReview(TripData trip) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DriverTripReviewScreen(trip: trip)),
    );
  }

  Future<void> _handleTripAction(String action) async {
    if (_activeTrip == null) return;
    final trip = _activeTrip!;
    final tripId = trip.id;
    Map<String, dynamic> res;
    switch (action) {
      case 'arrived':
        res = await ApiService.markArrived(tripId);
        break;
      case 'start':
        final otp = await _askTripOtp();
        if (otp == null) return;
        res = await ApiService.verifyTripOtp(tripId, otp);
        break;
      case 'complete':
        // Calculate actual km and minutes for the backend
        double actualKm = trip.tripDistanceKm;
        if (_currentLat != 0 && trip.pickupLat != null && trip.pickupLng != null) {
          actualKm = Geolocator.distanceBetween(
            trip.pickupLat!, trip.pickupLng!,
            _currentLat, _currentLng,
          ) / 1000.0;
        }
        int actualMinutes = 0;
        if (_tripStartedAt != null) {
          actualMinutes = DateTime.now().difference(_tripStartedAt!).inMinutes;
          if (actualMinutes < 1) actualMinutes = 1;
        }

        setState(() => _loadingActive = true);
        res = await ApiService.completeTrip(tripId,
            actualKm: actualKm, actualMinutes: actualMinutes);
        setState(() => _loadingActive = false);

        if (res['success'] == true) {
          final data = Map<String, dynamic>.from(res['data'] ?? res);
          if (data['trip_id'] == null) {
            data['trip_id'] = tripId;
          }
          await _processTripCompletion(data);
        } else {
          _showSnack(res['error'] ?? 'Trip completion failed', isError: true);
        }
        return;
      case 'cash':
        setState(() => _loadingActive = true);
        final earningsRes = await ApiService.getTripEarnings(tripId);
        res = await ApiService.markCashCollected(tripId);
        setState(() => _loadingActive = false);
        if (res['success'] == true) {
          final earningsData = earningsRes['success'] == true ? (earningsRes['data'] ?? earningsRes) : {};
          final Map<String, dynamic> data = Map<String, dynamic>.from({
            ...earningsData,
            ...res['data'] ?? res,
            'cash_collected': earningsData['actual_fare'] ?? res['amount'],
            'promo_discount': earningsData['promo_discount'],
            'commission_deducted': earningsData['platform_fee'],
            'company_pays_you': earningsData['company_payable'],
            'your_net_earnings': earningsData['driver_earnings'],
          });
          await _showCashCollectedBreakdown(data);
        }
        break;
      case 'cancel':
        final reason = await _askCancelReason();
        if (reason == null) return;
        res = await ApiService.cancelDriverTrip(tripId, reason);
        break;
      case 'sos':
        await ApiService.raiseSOS(tripId);
        _showSnack('🚨 SOS Alert raised! Help is on the way.', isError: false);
        return;
      default:
        return;
    }
    if (res['success']) {
      if (action == 'complete' || action == 'cash' || action == 'cancel') {
        _clearRoute();
        if (action == 'complete') _showSnack('Trip completed! 🎉', isError: false);
        if (action == 'cash') _showSnack('Cash collection confirmed.', isError: false);
        if (action == 'cancel') _showSnack('Ride cancelled.', isError: false);
        
        if (action != 'cancel') await _askDriverReview(trip);
        setState(() => _activeTrip = null);
        _loadEarnings();
      } else {
        _showSnack('Status updated', isError: false);
        await _checkActiveTrip();
        _drawTripRoute();
        if (action == 'start') {
          _tripStartedAt = DateTime.now();
          if (_activeTrip != null && _activeTrip!.dropLat != null && _activeTrip!.dropLng != null) {
            _openNavigation(_activeTrip!.dropLat!, _activeTrip!.dropLng!);
          }
        }
      }
    } else {
      _showSnack(res['error'], isError: true);
    }
  }

  void _clearRoute() {
    if (_mapController != null) {
      _mapController!.clearLines();
      if (_pickupSymbol != null) {
        try {
          _mapController!.removeSymbol(_pickupSymbol!);
        } catch (_) {}
        _pickupSymbol = null;
      }
      if (_dropSymbol != null) {
        try {
          _mapController!.removeSymbol(_dropSymbol!);
        } catch (_) {}
        _dropSymbol = null;
      }
    }
  }

  Future<void> _registerCustomIcons(MapplsMapController controller) async {
    // Register dynamic pins
    Future<Uint8List> drawMarker(Color color) async {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      const double size = 64.0;
      
      // Draw outer shadow/border
      final Paint shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2 + 2), 26.0, shadowPaint);

      // Draw outer white circle
      final Paint whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), 24.0, whitePaint);
      
      // Draw inner colored circle
      final Paint colorPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), 18.0, colorPaint);

      // Draw center white dot
      final Paint dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(size / 2, size / 2), 6.0, dotPaint);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
      final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    }

    try {
      if (!_registeredIcons.contains('pickup-pin')) {
        final bytes = await drawMarker(const Color(0xFF4CAF50)); // Green
        await controller.addImage('pickup-pin', bytes);
        _registeredIcons.add('pickup-pin');
        debugPrint("Successfully registered dynamic map icon: pickup-pin");
      }
      if (!_registeredIcons.contains('drop-pin')) {
        final bytes = await drawMarker(const Color(0xFFE53935)); // Red
        await controller.addImage('drop-pin', bytes);
        _registeredIcons.add('drop-pin');
        debugPrint("Successfully registered dynamic map icon: drop-pin");
      }
    } catch (e) {
      debugPrint("Failed to register dynamic marker pins: $e");
    }
  }

  Future<void> _drawTripRoute() async {
    if (_activeTrip == null || _mapController == null) return;

    await _registerCustomIcons(_mapController!);
    
    final status = _normalizeTripStatus(_activeTrip!.status);
    LatLng? source;
    LatLng? destination;
    
    if (status == 'accepted' || status == 'driver_assigned' || status == 'arrived') {
      // Driver to Pickup
      if (_currentLat != 0 && _activeTrip!.pickupLat != null) {
        source = LatLng(_currentLat, _currentLng);
        destination = LatLng(_activeTrip!.pickupLat!, _activeTrip!.pickupLng!);
      }
    } else if (status == 'started') {
      // Pickup to Drop
      if (_activeTrip!.pickupLat != null && _activeTrip!.dropLat != null) {
        source = LatLng(_activeTrip!.pickupLat!, _activeTrip!.pickupLng!);
        destination = LatLng(_activeTrip!.dropLat!, _activeTrip!.dropLng!);
      }
    }

    // Clear old symbols
    if (_pickupSymbol != null) {
      try {
        await _mapController!.removeSymbol(_pickupSymbol!);
      } catch (_) {}
      _pickupSymbol = null;
    }
    if (_dropSymbol != null) {
      try {
        await _mapController!.removeSymbol(_dropSymbol!);
      } catch (_) {}
      _dropSymbol = null;
    }

    // Add symbols if active trip has valid lat/lngs
    if (_activeTrip!.pickupLat != null && _activeTrip!.pickupLng != null) {
      try {
        _pickupSymbol = await _mapController!.addSymbol(SymbolOptions(
          geometry: LatLng(_activeTrip!.pickupLat!, _activeTrip!.pickupLng!),
          iconImage: 'pickup-pin',
          iconSize: 0.6,
          textField: 'Pickup',
          textOffset: const Offset(0, 1.8),
          textColor: '#4CAF50',
          textSize: 11.0,
        ));
      } catch (_) {}
    }

    if (_activeTrip!.dropLat != null && _activeTrip!.dropLng != null) {
      try {
        _dropSymbol = await _mapController!.addSymbol(SymbolOptions(
          geometry: LatLng(_activeTrip!.dropLat!, _activeTrip!.dropLng!),
          iconImage: 'drop-pin',
          iconSize: 0.6,
          textField: 'Drop',
          textOffset: const Offset(0, 1.8),
          textColor: '#E53935',
          textSize: 11.0,
        ));
      } catch (_) {}
    }

    if (source != null && destination != null) {
      List<LatLng> points = await MapService.getRoute(source, destination);
      if (points.isEmpty) {
        points = [source, destination];
      }
      if (points.isNotEmpty && _mapController != null) {
        _mapController!.clearLines();

        // Auto-zoom to fit the route
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              source.latitude < destination.latitude ? source.latitude : destination.latitude,
              source.longitude < destination.longitude ? source.longitude : destination.longitude,
            ),
            northeast: LatLng(
              source.latitude > destination.latitude ? source.latitude : destination.latitude,
              source.longitude > destination.longitude ? source.longitude : destination.longitude,
            ),
          ),
          left: 50, right: 50, top: 120, bottom: 250,
        ));
      }
    }
  }

  Future<void> _loadEarnings() async {
    final res = await ApiService.getEarningsSummary();
    if (res['success'] && mounted) {
      final data = res['data'];
      final wb = (data['wallet_balance'] ?? 0.0).toDouble();
      await AuthService.updateWallet(wb);
      setState(() => _earningsRaw = data);
    }
  }

  void _showWithdrawDialog(BuildContext context) {
    final double balance = double.tryParse(_earnings.wallet) ?? AuthService.walletBalance;
    final amountCtrl = TextEditingController();
    final upiCtrl = TextEditingController();
    bool isWithdrawing = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Withdraw Earnings',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kDark,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Balance: ₹${balance.toStringAsFixed(2)}',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kSuccess,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !isWithdrawing,
                    style: GoogleFonts.sora(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: GoogleFonts.sora(fontSize: 12),
                      hintText: 'Enter amount to withdraw',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: upiCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isWithdrawing,
                    style: GoogleFonts.sora(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'UPI ID',
                      labelStyle: GoogleFonts.sora(fontSize: 12),
                      hintText: 'e.g. name@upi',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.account_balance, size: 16),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: GoogleFonts.sora(
                        color: kError,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isWithdrawing
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.sora(color: kMuted, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: isWithdrawing
                      ? null
                      : () async {
                          final String amtStr = amountCtrl.text.trim();
                          final String upiStr = upiCtrl.text.trim();

                          if (amtStr.isEmpty) {
                            setDialogState(() => errorText = 'Amount is required');
                            return;
                          }
                          final double? amt = double.tryParse(amtStr);
                          if (amt == null || amt <= 0) {
                            setDialogState(() => errorText = 'Enter a valid amount');
                            return;
                          }
                          if (amt > balance) {
                            setDialogState(() => errorText = 'Insufficient balance');
                            return;
                          }
                          if (upiStr.isEmpty) {
                            setDialogState(() => errorText = 'UPI ID is required');
                            return;
                          }
                          if (!upiStr.contains('@')) {
                            setDialogState(() => errorText = 'Enter a valid UPI ID');
                            return;
                          }

                          setDialogState(() {
                            isWithdrawing = true;
                            errorText = null;
                          });

                          final res = await ApiService.requestWithdrawal(amt, upiStr);

                          if (res['success'] == true) {
                            final double newBal = (res['data']?['new_balance'] ?? 0.0).toDouble();
                            await AuthService.updateWallet(newBal);
                            await _loadEarnings();
                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              _showSnack('Withdrawal of ₹$amt requested successfully!', isError: false);
                            }
                          } else {
                            if (mounted) {
                              setDialogState(() {
                                isWithdrawing = false;
                                errorText = res['error'] ?? 'Withdrawal request failed';
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: isWithdrawing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: kWhite,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Withdraw',
                          style: GoogleFonts.sora(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _refreshProfileStatus() async {
    final res = await ApiService.getMe();
    if (res['success']) {
      final data = res['data'];
      debugPrint('GETME DATA: $data');
      final driver = data['driver'];
      if (driver != null) {
        await AuthService.updateApprovalStatus(driver['is_approved'] == true);
        final pic = driver['profile_pic_url'] ?? data['profile_pic'] ?? '';
        if ((pic as String).isNotEmpty) await AuthService.updateProfilePic(pic);
        
        final online = driver['is_online'] == true;
        await AuthService.setIsOnline(online);
        _isOnline = online;
        if (online) {
          _connectDriverSocket();
        }
      }
      if (mounted) setState(() {});
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.sora(fontSize: 13)),
      backgroundColor: isError ? kError : kSuccess,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  EarningsData get _earnings {
    if (_earningsRaw == null) {
      return EarningsData(
          wallet: AuthService.walletBalance.toStringAsFixed(0),
          today: '0',
          week: '0',
          month: '0',
          allTime: '0',
          trips: 0);
    }
    final today = _earningsRaw!['today'] ?? {};
    final week = _earningsRaw!['this_week'] ?? {};
    final month = _earningsRaw!['this_month'] ?? {};
    final allTime = _earningsRaw!['all_time'] ?? {};
    return EarningsData(
      wallet: AuthService.walletBalance.toStringAsFixed(0),
      today: '${today['earnings'] ?? 0}',
      week: '${week['earnings'] ?? 0}',
      month: '${month['earnings'] ?? 0}',
      allTime: '${allTime['earnings'] ?? 0}',
      trips: today['trips'] ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: kScaffoldBg,
        body: IndexedStack(
          index: _navIndex,
          children: [
            _buildMainMapArea(),
            EarningsScreen(
                earnings: _earnings,
                onClose: () => setState(() => _navIndex = 0),
                onWithdrawPressed: () => _showWithdrawDialog(context)),
            _historyTab(),
            _profileTab(),
          ],
        ),
        bottomNavigationBar: _activeTrip == null
            ? Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        _buildBottomNavItem(Icons.home_rounded, 'Home', 0),
                        _buildBottomNavItem(Icons.directions_car_outlined, 'My Rides', 2),
                        _buildBottomNavItem(Icons.account_balance_wallet_outlined, 'Earnings', 1),
                        _buildBottomNavItem(Icons.person_outline_rounded, 'Profile', 3),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int targetIndex) {
    final selected = _navIndex == targetIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _navIndex = targetIndex),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? kOrange : const Color(0xFFAAAAAA),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kOrange : const Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: kGray2, width: 1.0),
      ),
      child: Row(
        children: [
          // K logo
          Flexible(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'K',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Ride',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      color: kDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Offline/Online pill
          Flexible(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOnline ? kSuccess : const Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isOnline ? 'ONLINE' : 'OFFLINE',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Bell icon with dot
          GestureDetector(
            onTap: () {
              _showSnack('No new notifications', isError: false);
            },
            child: Stack(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 24, color: kDark),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Profile avatar
          GestureDetector(
            onTap: () => setState(() => _navIndex = 3), // Go to Profile
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFCCCCCC),
              ),
              child: ClipOval(
                child: AuthService.profilePic.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: AuthService.profilePic,
                        fit: BoxFit.cover,
                        width: 32,
                        height: 32,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapZoomControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _mapButton(Icons.add),
        const SizedBox(height: 8),
        _mapButton(Icons.remove),
        const SizedBox(height: 8),
        _mapButton(Icons.my_location),
      ],
    );
  }

  Widget _mapButton(IconData icon) {
    return GestureDetector(
      onTap: () {
        if (_mapController == null) return;
        if (icon == Icons.add) {
          _mapController!.animateCamera(CameraUpdate.zoomIn());
        } else if (icon == Icons.remove) {
          _mapController!.animateCamera(CameraUpdate.zoomOut());
        } else if (icon == Icons.my_location) {
          if (_currentLat != 0 && _currentLng != 0) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(_currentLat, _currentLng),
                  zoom: 15.0,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: kDark),
      ),
    );
  }

  Widget _buildGoOnlineButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _toggling ? null : _handleToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _isOnline ? const Color(0xFF27AE60) : kOrange,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (_isOnline ? const Color(0xFF27AE60) : kOrange)
                    .withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_toggling)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.power_settings_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                          style: GoogleFonts.sora(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isOnline
                              ? 'You are receiving ride requests'
                              : 'Start receiving ride requests',
                          style: GoogleFonts.sora(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Scheduled Rides
            _buildInfoRow(
              iconWidget: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kOrangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    color: kOrange, size: 24),
              ),
              title: 'Scheduled Rides',
              subtitle: 'No upcoming rides',
              trailing: Row(
                children: [
                  Text(
                    'View All',
                    style: GoogleFonts.sora(
                      color: kOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: kOrange, size: 20),
                ],
              ),
              onTap: () {
                _showSnack('No scheduled rides available', isError: false);
              },
            ),
            // Divider
            const Divider(height: 1, thickness: 1, color: kGray2,
                indent: 16, endIndent: 16),
            // Admin Settlement
            _buildInfoRow(
              iconWidget: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF7F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: kSuccess, size: 24),
              ),
              title: 'Admin Settlement',
              subtitle: 'Wallet Balance',
              trailing: Row(
                children: [
                  Text(
                    '₹${AuthService.walletBalance.toStringAsFixed(0)}',
                    style: GoogleFonts.sora(
                      color: kSuccess,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: kMuted, size: 20),
                ],
              ),
              onTap: () {
                setState(() => _navIndex = 1); // Switch to Earnings/Stats Screen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        color: kMuted,
                      )),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: kSuccess,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '₹',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Earnings",
                      style: GoogleFonts.sora(fontSize: 10, color: kMuted),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '₹${_earnings.today}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_upward,
                            size: 10, color: kSuccess),
                        Text(
                          '12%',
                          style: GoogleFonts.sora(
                              fontSize: 9,
                              color: kSuccess,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Vertical divider
              Container(
                  width: 1, height: 60, color: kGray2),

              // Trips
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: kInfo,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Trips',
                      style: GoogleFonts.sora(fontSize: 10, color: kMuted),
                    ),
                    Text(
                      '${_earnings.trips}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kDark,
                      ),
                    ),
                    Text(
                      'Completed',
                      style: GoogleFonts.sora(fontSize: 10, color: kMuted),
                    ),
                  ],
                ),
              ),

              // Vertical divider
              Container(
                  width: 1, height: 60, color: kGray2),

              // Rating
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5A623),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rating',
                      style: GoogleFonts.sora(fontSize: 10, color: kMuted),
                    ),
                    Text(
                      '5.0',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kDark,
                      ),
                    ),
                    Text(
                      'Top Rated',
                      style: GoogleFonts.sora(fontSize: 10, color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainMapArea() {
    Widget mainContent;

    if (_activeTrip != null) {
      mainContent = Stack(
        children: [
          MapplsMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentLat != 0 ? _currentLat : 22.5726, 
                             _currentLng != 0 ? _currentLng : 88.3639),
              zoom: 14.0,
            ),
            myLocationEnabled: true,
            onMapCreated: (MapplsMapController controller) {
              _mapController = controller;
              _registeredIcons.clear();
              _drawTripRoute();
            },
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 80,
            child: _buildMapZoomControls(),
          ),
          ActiveTripPanel(
            trip: _activeTrip!,
            onAction: _handleTripAction,
            onCall: _callRider,
            onChat: _openRiderChat,
            onNavigate: _openNavigation,
          ),
        ],
      );
    } else {
      mainContent = Column(
        children: [
          Expanded(
            flex: 65,
            child: Stack(
              children: [
                MapplsMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentLat != 0 ? _currentLat : 22.5726, 
                                   _currentLng != 0 ? _currentLng : 88.3639),
                    zoom: 14.0,
                  ),
                  myLocationEnabled: true,
                  onMapCreated: (MapplsMapController controller) {
                    _mapController = controller;
                    _registeredIcons.clear();
                  },
                ),
                // Floating AppBar with rounded corners
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 12,
                  right: 12,
                  child: _buildAppBar(),
                ),
                // Zoom controls positioned below the floating AppBar card
                Positioned(
                  right: 12,
                  top: MediaQuery.of(context).padding.top + 80,
                  child: _buildMapZoomControls(),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGray2),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: Text('🗺️ Live Mappls Navigation',
                         style: GoogleFonts.sora(
                            fontSize: 9,
                            color: kMuted,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 35,
            child: Container(
              color: kScaffoldBg,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildGoOnlineButton(),
                    const SizedBox(height: 16),
                    _buildInfoCards(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        mainContent,
        if (_incomingTrip != null && _activeTrip == null)
          Positioned.fill(
            child: IncomingTripModal(
              trip: _incomingTrip!,
              onAccept: _handleAccept,
              onDecline: _handleDecline,
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HISTORY TAB
  // ══════════════════════════════════════════════════════════════
  Widget _historyTab() => SafeArea(
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text('Trip History',
                  style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kDark))),
          Expanded(
              child: FutureBuilder(
            future: ApiService.getDriverHistory(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const Center(
                    child: CircularProgressIndicator(color: kOrange));
              final res = snap.data as Map<String, dynamic>?;              if (res == null || !res['success'])
                return Center(
                    child: Text('Could not load trips',
                        style: GoogleFonts.sora(color: kMuted)));
              final trips = res['data']['trips'] as List;
              if (trips.isEmpty)
                return const Center(child: Text('No trips yet!'));
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  itemBuilder: (_, i) => _histCard(trips[i]));
            },
          )),
        ]),
      );

  Widget _histCard(Map trip) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('#${trip['trip_code']}',
                style: GoogleFonts.sora(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kMuted)),
            _badge(trip['status']),
          ]),
          const SizedBox(height: 6),
          Text(trip['pickup_address'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 13, color: kDark)),
          Text('→ ${trip['drop_address'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(fontSize: 13, color: kMuted)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('₹${trip['driver_earnings'] ?? trip['estimated_fare']}',
                style: GoogleFonts.sora(
                    fontSize: 15, fontWeight: FontWeight.w800, color: kOrange)),
            Text('${trip['distance_km']} km',
                style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
          ]),
        ]),
      );

  Widget _badge(String? status) {
    Color c = kMuted;
    if (status == 'completed') c = kSuccess;
    if (status == 'cancelled') c = kError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text((status ?? '').toUpperCase(),
          style: GoogleFonts.sora(
              fontSize: 10, color: c, fontWeight: FontWeight.w700)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PROFILE TAB
  // ══════════════════════════════════════════════════════════════
  Widget _profileTab() {
    final isApproved = AuthService.isApproved;
    final profilePic = AuthService.profilePic;
    debugPrint('PROFILE PIC URL: $profilePic');

    return SafeArea(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 10),
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isApproved ? kSuccess : kOrange, width: 3)),
            child: ClipOval(
                child: profilePic.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profilePic,
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => _avatarFallback(),
                      )
                    : _avatarFallback()),
          ),
          Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: kMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: kWhite, width: 2)),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 12))),
        ]),
        const SizedBox(height: 12),
        Text(AuthService.name,
            style: GoogleFonts.sora(
                fontSize: 18, fontWeight: FontWeight.w700, color: kDark)),
        Text('+91 ${AuthService.phone}',
            style: GoogleFonts.sora(fontSize: 13, color: kMuted)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isApproved
                ? kSuccess.withOpacity(0.1)
                : kOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isApproved
                    ? kSuccess.withOpacity(0.4)
                    : kOrange.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                isApproved
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                size: 16,
                color: isApproved ? kSuccess : kOrange),
            const SizedBox(width: 6),
            Text(isApproved ? 'Profile Approved ✅' : 'Under verification ⏳',
                style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isApproved ? kSuccess : kOrange)),
          ]),
        ),
        const SizedBox(height: 30),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.description_rounded, color: kOrange),
          ),
          title: Text('My Documents',
              style: GoogleFonts.sora(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
          trailing: const Icon(Icons.chevron_right_rounded, color: kMuted),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyDocumentsScreen(driverId: AuthService.driverId)));
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.share_rounded, color: kOrange),
          ),
          title: Text('Refer a Friend',
              style: GoogleFonts.sora(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
          trailing: const Icon(Icons.chevron_right_rounded, color: kMuted),
          onTap: _showReferralBottomSheet,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.headset_mic_rounded, color: kOrange),
          ),
          title: Text('Support & Help',
              style: GoogleFonts.sora(
                  fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
          trailing: const Icon(Icons.chevron_right_rounded, color: kMuted),
          onTap: _showSupportBottomSheet,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
                  (r) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kError.withOpacity(0.1),
              foregroundColor: kError,
              elevation: 0,
            ),
            child: const Text('Log Out'),
          ),
        ),
      ]),
    ));
  }

  void _showReferralBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 30),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: ApiService.getMe(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 250,
                  child: Center(
                    child: CircularProgressIndicator(color: kOrange),
                  ),
                );
              }

              // Extract the referral code safely
              final data = snapshot.data?['data'];
              final referralCode = data?['referral_code']?.toString() ?? 'KRIDE50';

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gift Icon/Emoji with pulsing border effect or stylish box
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kOrangeLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: kOrange.withOpacity(0.2), width: 2),
                      ),
                      child: const Center(
                        child: Text('🎁', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Refer a Friend & Earn! 👥',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    Text(
                      'Share your unique referral code with friends. When they register and take their first ride, both of you will receive bonus rewards! 🎁',
                      style: GoogleFonts.sora(
                        fontSize: 13.5,
                        color: kMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Referral Code Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBFBFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'YOUR REFERRAL CODE',
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Dashed-style look with rounded orange text
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: kOrangeLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kOrange.withOpacity(0.3),
                                style: BorderStyle.solid,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              referralCode,
                              style: GoogleFonts.sora(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: kOrange,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Copy Code Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: referralCode));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Referral code "$referralCode" copied to clipboard! 🎁',
                                  style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              backgroundColor: kOrange,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          'Copy Referral Code',
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _supportOptionTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kGray,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: kMuted, size: 14),
          ],
        ),
      ),
    );
  }

  void _showSupportBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 20),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 20),
              Text('Contact Support 💬',
                  style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kDark)),
              const SizedBox(height: 12),
              Text(
                  'Need assistance with your rides or driver portal?',
                  style: GoogleFonts.sora(fontSize: 14, color: kMuted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              _supportOptionTile(
                icon: '📞',
                title: 'Call Support Helpline',
                subtitle: 'Instant phone support (24/7)',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Calling Helpline: +91 1800-KRIDE 📞',
                              style: GoogleFonts.sora(fontSize: 13)),
                          backgroundColor: kOrange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))));
                },
              ),
              _supportOptionTile(
                icon: '🟢',
                title: 'Chat on WhatsApp',
                subtitle: 'Get support via WhatsApp chat',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Opening WhatsApp Support Chat 🟢',
                              style: GoogleFonts.sora(fontSize: 13)),
                          backgroundColor: kOrange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))));
                },
              ),
              _supportOptionTile(
                icon: '✉️',
                title: 'Email support',
                subtitle: 'support@kride.app',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Opening email compose ✉️',
                              style: GoogleFonts.sora(fontSize: 13)),
                          backgroundColor: kOrange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
      color: kGray2, child: const Icon(Icons.person, color: kMuted, size: 40));
}
