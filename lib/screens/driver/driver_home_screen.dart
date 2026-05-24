import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/driver_socket_service.dart';
import '../../services/ride_alert_service.dart';
import '../auth/role_selection_screen.dart';
import 'my_documents_screen.dart';

// ── Colour tokens ────────────────────────────────────────────
const kOrange      = Color(0xFFFF6B00);
const kOrangeDark  = Color(0xFFE55A00);
const kOrangeLight = Color(0xFFFFF3E8);
const kWhite       = Color(0xFFFFFFFF);
const kGray        = Color(0xFFF6F6F6);
const kGray2       = Color(0xFFEEEEEE);
const kDark        = Color(0xFF1A1A1A);
const kMuted       = Color(0xFF9E9E9E);
const kSuccess     = Color(0xFF00C853);
const kError       = Color(0xFFFF3B3B);
const kInfo        = Color(0xFF3B82F6);

// ── Data models ──────────────────────────────────────────────
class TripData {
  final int    id;
  final int    fare;
  final int    driverEarnings;
  final String pickup;
  final String drop;
  final String distance;
  final String duration;
  final String payment;
  final String riderRating;
  final String riderName;
  final String vehicle;
  String       status; // requested | accepted | arrived | started

  TripData({
    required this.id,
    required this.fare,
    required this.driverEarnings,
    required this.pickup,
    required this.drop,
    required this.distance,
    required this.duration,
    required this.payment,
    required this.riderRating,
    required this.riderName,
    required this.vehicle,
    required this.status,
  });

  TripData copyWith({String? status}) => TripData(
    id: id, fare: fare, driverEarnings: driverEarnings,
    pickup: pickup, drop: drop, distance: distance, duration: duration,
    payment: payment, riderRating: riderRating, riderName: riderName,
    vehicle: vehicle, status: status ?? this.status,
  );
}

class EarningsData {
  final String wallet;
  final String today;
  final String week;
  final String month;
  final String allTime;
  final int    trips;
  const EarningsData({
    required this.wallet, required this.today, required this.week,
    required this.month,  required this.allTime, required this.trips,
  });
}

TripData _mapToTripData(Map<String, dynamic> data) {
  return TripData(
    id: data['id'],
    fare: data['estimated_fare']?.toInt() ?? 0,
    driverEarnings: data['driver_earnings'] != null ? double.parse(data['driver_earnings'].toString()).toInt() : (data['estimated_fare']?.toInt() ?? 0),
    pickup: data['pickup_address'] ?? 'Unknown',
    drop: data['drop_address'] ?? 'Unknown',
    distance: data['distance_km']?.toString() ?? '0',
    duration: data['duration_min']?.toString() ?? '0',
    payment: data['payment_method'] ?? 'Cash',
    riderRating: '5.0',
    riderName: data['rider'] != null ? data['rider']['name'] : 'Rider',
    vehicle: (data['vehicle_type'] ?? 'cab').toString().toUpperCase(),
    status: data['status'] ?? 'requested',
  );
}

// ══════════════════════════════════════════════════════════════
//  ANIMATED MAP
// ══════════════════════════════════════════════════════════════
class MapPainter extends CustomPainter {
  final bool   isOnline;
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
    [0.02, 0.02, 0.18, 0.12], [0.02, 0.18, 0.18, 0.10],
    [0.28, 0.02, 0.14, 0.10], [0.28, 0.18, 0.14, 0.26],
    [0.46, 0.02, 0.16, 0.10], [0.46, 0.18, 0.16, 0.10],
    [0.66, 0.02, 0.12, 0.26], [0.82, 0.02, 0.16, 0.12],
    [0.82, 0.18, 0.16, 0.10], [0.02, 0.64, 0.18, 0.18],
    [0.28, 0.48, 0.14, 0.14], [0.46, 0.48, 0.16, 0.14],
    [0.66, 0.48, 0.12, 0.14], [0.66, 0.64, 0.12, 0.18],
    [0.82, 0.64, 0.16, 0.18], [0.28, 0.64, 0.14, 0.18],
    [0.46, 0.64, 0.16, 0.18],
  ];

  const MapPainter({required this.isOnline, required this.t, required this.driverPos});

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
      ..color = isOnline ? kOrange.withOpacity(0.07) : Colors.black.withOpacity(0.05);
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
      p.color = Color.fromARGB(255, shade.toInt(), (shade - 2).clamp(0, 255).toInt(), (shade - 4).clamp(0, 255).toInt());
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
      RRect.fromRectAndRadius(Rect.fromLTWH(W * 0.47, H * 0.32, W * 0.16, H * 0.12), const Radius.circular(6)),
      p,
    );

    // Roads
    final roadPaint = Paint()
      ..style  = PaintingStyle.stroke
      ..color  = const Color(0xFFE8E0D5)
      ..strokeCap = StrokeCap.round;
    final dashPaint = Paint()
      ..style  = PaintingStyle.stroke
      ..color  = const Color(0xFFB4AAA0).withOpacity(0.5)
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
      final pulsePaint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final r = _roads[i];
        pulsePaint
          ..color       = kOrange.withOpacity(0.06 + pulse * 0.08)
          ..strokeWidth = r[4] * 0.35;
        canvas.drawLine(Offset(r[0] * W, r[1] * H), Offset(r[2] * W, r[3] * H), pulsePaint);
      }
    }

    // Driver location
    final dpx = driverPos.dx * W;
    final dpy = driverPos.dy * H;
    final pulse2 = (sin(t * 0.003) + 1) / 2;

    canvas.drawCircle(Offset(dpx, dpy), 32 + pulse2 * 10, Paint()..color = kOrange.withOpacity(0.08 + pulse2 * 0.06));
    canvas.drawCircle(Offset(dpx, dpy), 20, Paint()..color = kOrange.withOpacity(0.18));
    canvas.drawCircle(Offset(dpx, dpy), 14, Paint()..color = kWhite);
    canvas.drawCircle(Offset(dpx, dpy), 14, Paint()..style = PaintingStyle.stroke..color = kOrange..strokeWidth = 2.5);

    // Car emoji via TextPainter
    final tp = TextPainter(
      text: const TextSpan(text: '🚗', style: TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(dpx - tp.width / 2, dpy - 24 - tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashLen, double gapLen) {
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
  final bool   isOnline;
  final Offset driverPos;
  const MapBackground({super.key, required this.isOnline, required this.driverPos});

  @override
  State<MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<MapBackground> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _t = elapsed.inMilliseconds.toDouble());
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MapPainter(isOnline: widget.isOnline, t: _t, driverPos: widget.driverPos),
      child: const SizedBox.expand(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  INCOMING TRIP MODAL
// ══════════════════════════════════════════════════════════════
class IncomingTripModal extends StatefulWidget {
  final TripData  trip;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const IncomingTripModal({super.key, required this.trip, required this.onAccept, required this.onDecline});

  @override
  State<IncomingTripModal> createState() => _IncomingTripModalState();
}

class _IncomingTripModalState extends State<IncomingTripModal> with SingleTickerProviderStateMixin {
  int    _timer    = 20;
  double _progress = 1.0; 
  Timer? _countdown;
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))..forward();
    _slideAnim = Tween(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.elasticOut));

    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timer--;
        _progress = (_timer / 20).clamp(0.0, 1.0);
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
    return GestureDetector(
      onTap: () {}, 
      child: Container(
        color: Colors.black.withOpacity(0.45),
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, -8))],
              border: Border.all(color: kOrange.withOpacity(0.13)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 4, color: kGray2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        widthFactor: _progress,
                        duration: const Duration(seconds: 1),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [kOrange, kOrangeDark]),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [BoxShadow(color: kOrange.withOpacity(0.53), blurRadius: 6)],
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
                              style: GoogleFonts.sora(fontSize: 11, color: kOrange, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          Text.rich(TextSpan(
                            text: '₹${widget.trip.fare} ',
                            style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: kDark),
                            children: [TextSpan(text: 'estimated', style: GoogleFonts.sora(fontSize: 13, color: kMuted, fontWeight: FontWeight.w500))],
                          )),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 56, height: 56,
                      child: CustomPaint(
                        painter: _CountdownPainter(progress: _progress),
                        child: Center(
                          child: Text('$_timer', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, color: kOrange)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: kSuccess, boxShadow: [BoxShadow(color: kSuccess, blurRadius: 6)])),
                              Container(width: 1.5, height: 26, color: kGray2),
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: kOrange, blurRadius: 6)])),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PICKUP', style: GoogleFonts.sora(fontSize: 10, color: kMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                const SizedBox(height: 3),
                                Text(widget.trip.pickup, style: GoogleFonts.sora(fontSize: 13, color: kDark, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                Text('DROP-OFF', style: GoogleFonts.sora(fontSize: 10, color: kMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                                const SizedBox(height: 3),
                                Text(widget.trip.drop, style: GoogleFonts.sora(fontSize: 13, color: kDark, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _MetaChip(icon: '📍', value: '${widget.trip.distance} km'),
                          _MetaChip(icon: '⏱️', value: '${widget.trip.duration} min'),
                          _MetaChip(icon: '💵', value: widget.trip.payment),
                          _MetaChip(icon: '⭐', value: widget.trip.riderRating),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kOrangeLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kOrange.withOpacity(0.2), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('💰 Your earnings', style: GoogleFonts.sora(fontSize: 13, color: kOrange, fontWeight: FontWeight.w600)),
                      Text('₹${widget.trip.driverEarnings}', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: kOrange)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _OutlineBtn(label: 'Decline', onTap: widget.onDecline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _GradientBtn(label: 'Accept Ride ✓', onTap: widget.onAccept),
                    ),
                  ],
                ),
              ],
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
    canvas.drawCircle(center, radius, Paint()..color = kGray2..style = PaintingStyle.stroke..strokeWidth = 4);

    final arcPaint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color       = kOrange
      ..strokeCap   = StrokeCap.round;
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
  final TripData    trip;
  final Function(String) onAction;
  const ActiveTripPanel({super.key, required this.trip, required this.onAction});

  static const _steps = [
    ('accepted', 'Head to Pickup',    'arrived',  "I've Arrived",  kInfo,    '🚗'),
    ('arrived',  'Waiting for Rider', 'start',    'Start Trip',    kOrange,  '⏳'),
    ('started',  'Trip in Progress',  'complete', 'Complete Trip', kSuccess, '🛣️'),
  ];

  @override
  Widget build(BuildContext context) {
    final cur = _steps.firstWhere((s) => s.$1 == trip.status, orElse: () => _steps[0]);
    final color  = cur.$5 as Color;
    final icon   = cur.$6;
    final label  = cur.$2;
    final btn    = cur.$4;
    final action = cur.$3;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 40, offset: Offset(0, -8))],
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kGray2, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 20),

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
                        Text('ACTIVE TRIP', style: GoogleFonts.sora(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                        Text(label, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Your earnings', style: GoogleFonts.sora(fontSize: 10, color: kMuted)),
                      Text('₹${trip.driverEarnings}', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: kOrange)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    child: Center(child: Text(trip.riderName.isNotEmpty ? trip.riderName[0] : 'R', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: kWhite))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.riderName, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
                        Text('⭐ ${trip.riderRating} · ${trip.vehicle}', style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _CircleBtn(icon: '📞', bg: kSuccess.withOpacity(0.15), border: kSuccess.withOpacity(0.27)),
                      const SizedBox(width: 8),
                      _CircleBtn(icon: '💬', bg: kGray2, border: kGray2),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: kSuccess, boxShadow: [BoxShadow(color: kSuccess, blurRadius: 5)])),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(trip.pickup, style: GoogleFonts.sora(fontSize: 13, color: kDark))),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(width: 1.5, height: 12, color: const Color(0xFFCCCCCC)),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: kOrange, blurRadius: 5)])),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(trip.drop, style: GoogleFonts.sora(fontSize: 13, color: kDark))),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: color.withOpacity(0.27),
                ),
                child: Text('$btn →', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
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
  const EarningsScreen({super.key, required this.earnings, required this.onClose});

  static const _periods = [
    ('Today',      '☀️',  3),
    ('This Week',  '📅',  18),
    ('This Month', '🗓️', 74),
    ('All Time',   '🏆', 312),
  ];

  @override
  Widget build(BuildContext context) {
    final amts = [earnings.today, earnings.week, earnings.month, earnings.allTime];

    return Container(
      color: kWhite,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kGray2))),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(12), border: Border.all(color: kGray2)), child: const Center(child: Text('←', style: TextStyle(fontSize: 18, color: kDark)))),
                ),
                const SizedBox(width: 14),
                Text('My Earnings', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: kDark)),
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
                    gradient: const LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: kOrange.withOpacity(0.27), blurRadius: 40, offset: const Offset(0, 12))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet Balance', style: GoogleFonts.sora(fontSize: 12, color: const Color(0xBFFFFFFF))),
                      const SizedBox(height: 4),
                      Text('₹${earnings.wallet}', style: GoogleFonts.sora(fontSize: 38, fontWeight: FontWeight.w800, color: kWhite)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                _WalletStat(label: 'Today',     value: '₹${earnings.today}'),
                                const SizedBox(width: 20),
                                _WalletStat(label: 'This Week', value: '₹${earnings.week}'),
                                const SizedBox(width: 20),
                                _WalletStat(label: 'Trips',     value: '${earnings.trips}'),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kWhite,
                              side: const BorderSide(color: Color(0x4DFFFFFF)),
                              backgroundColor: Colors.white.withOpacity(0.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: Text('Withdraw', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700)),
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
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(_periods[i].$2, style: const TextStyle(fontSize: 20)))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_periods[i].$1, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
                              Text('${_periods[i].$3} trips', style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
                            ],
                          ),
                        ),
                        Text('₹${amts[i]}', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: kOrange)),
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
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 3),
          Text(value, style: GoogleFonts.sora(fontSize: 10, color: kDark, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

class _CircleBtn extends StatelessWidget {
  final String icon;
  final Color  bg, border;
  const _CircleBtn({required this.icon, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(shape: BoxShape.circle, color: bg, border: Border.all(color: border, width: 1.5)),
    child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
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
      decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(16), border: Border.all(color: kGray2)),
      child: Center(child: Text(label, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: kMuted))),
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
        gradient: const LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kOrange.withOpacity(0.27), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Center(child: Text(label, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: kWhite))),
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
      Text(label, style: GoogleFonts.sora(fontSize: 10, color: kWhite.withOpacity(0.65))),
      Text(value, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: kWhite)),
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
class _OnlineDotState extends State<_OnlineDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = Tween(begin: 1.0, end: 0.4).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOnline) return Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCCCCCC)));
    return FadeTransition(
      opacity: _anim,
      child: Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: kSuccess, boxShadow: [BoxShadow(color: kSuccess, blurRadius: 6)])),
    );
  }
}

// ── Toggle button ──
class _ToggleButton extends StatelessWidget {
  final bool isOnline, toggling;
  final AnimationController spinCtrl;
  final VoidCallback onTap;
  const _ToggleButton({required this.isOnline, required this.toggling, required this.spinCtrl, required this.onTap});

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
              ? const LinearGradient(colors: [Color(0xFFF0FFF4), Color(0xFFE8F5E9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : const LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: isOnline ? Border.all(color: kSuccess.withOpacity(0.27), width: 2) : null,
          boxShadow: isOnline
              ? [BoxShadow(color: kSuccess.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4))]
              : [BoxShadow(color: kOrange.withOpacity(0.27), blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (toggling)
              RotationTransition(
                turns: spinCtrl,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border(
                      top:    BorderSide(color: isOnline ? kSuccess : kWhite, width: 3),
                      right:  const BorderSide(color: Colors.transparent, width: 3),
                      bottom: const BorderSide(color: Colors.transparent, width: 3),
                      left:   const BorderSide(color: Colors.transparent, width: 3),
                    ),
                  ),
                ),
              )
            else ...[
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? kSuccess.withOpacity(0.12) : Colors.white.withOpacity(0.18),
                  border: Border.all(color: isOnline ? kSuccess.withOpacity(0.4) : Colors.white.withOpacity(0.4), width: 2),
                ),
                child: const Center(child: Text('⚡', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isOnline ? 'Go Offline' : 'Go Online', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: isOnline ? kSuccess : kWhite)),
                  Text(isOnline ? 'Stop accepting rides' : 'Start earning now', style: GoogleFonts.sora(fontSize: 12, color: isOnline ? kSuccess.withOpacity(0.67) : kWhite.withOpacity(0.75))),
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
  final bool   danger;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.danger, required this.onTap});

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
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: accentColor.withOpacity(0.13), blurRadius: 14, offset: const Offset(0, 4))],
                border: Border.all(color: accentColor.withOpacity(0.13), width: 1.5),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: kDark), textAlign: TextAlign.center, maxLines: 1),
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
  const _StatCell({required this.label, required this.value, this.showDivider = false, this.last = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      decoration: showDivider && !last ? const BoxDecoration(border: Border(left: BorderSide(color: kGray2))) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: kDark)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.sora(fontSize: 9, color: kMuted, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
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

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  bool         _isOnline      = false;
  bool         _toggling      = false;
  TripData?    _incomingTrip;
  TripData?    _activeTrip;
  int          _navIndex      = 0;
  final Offset _driverPos     = const Offset(0.5, 0.42);
  String       _greeting      = 'Good morning';

  // Backend vars
  double _currentLat = 0;
  double _currentLng = 0;
  bool _loadingActive = false;
  Map<String, dynamic>? _earningsRaw;
  Timer? _tripPollingTimer;

  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
    final h = DateTime.now().hour;
    if (h < 12)      _greeting = 'Good morning';
    else if (h < 17) _greeting = 'Good afternoon';
    else             _greeting = 'Good evening';

    _getLocation();
    _loadEarnings();
    _checkActiveTrip();
    _refreshProfileStatus();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _tripPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
      await ApiService.updateLocation(_currentLat, _currentLng);
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen((pos) async {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        if (_isOnline) await ApiService.updateLocation(_currentLat, _currentLng);
      });
    } catch (_) {}
  }

  Future<void> _handleToggle() async {
    setState(() => _toggling = true);
    final res = await ApiService.toggleOnline();
    if (res['success']) {
      setState(() => _isOnline = res['data']['is_online']);
      _showSnack(res['data']['message'], isError: false);
      if (_isOnline) {

  await DriverSocketService.connect(
    AuthService.driverId,
  );

  DriverSocketService.onMessage = (
    data,
  ) {

    print(
      'Socket message: $data',
    );

    if (
      data['type'] == 'new_trip'
    ) {

      final tripData =
          data['data'];

      RideAlertService.startAlert();

      if (mounted) {

        setState(() {

          _incomingTrip =
              _mapToTripData(
            tripData,
          );

        });

      }

    }

    if (
      data['type'] ==
          'trip_taken'
    ) {

      _showSnack(
        'Trip already taken',
        isError: true,
      );

      if (mounted) {

        setState(() {

          _incomingTrip = null;

        });

      }

    }

  };

} else {

  DriverSocketService.disconnect();

  setState(() => _incomingTrip = null);

}
      _showSnack(res['error'], isError: true);
    }
    setState(() => _toggling = false);
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
      if (mounted) setState(() => _activeTrip = _mapToTripData(res['data']['active_trip']));
    } else {
      if (mounted) setState(() => _activeTrip = null);
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
    } else {
      _showSnack(res['error'], isError: true);
      await RideAlertService.stopAlert();
      setState(() => _incomingTrip = null);
    }
  }

  void _handleDecline() {
    setState(() => _incomingTrip = null);
  }

  Future<void> _handleTripAction(String action) async {
    if (_activeTrip == null) return;
    final tripId = _activeTrip!.id;
    Map<String, dynamic> res;
    switch (action) {
      case 'arrived':  res = await ApiService.markArrived(tripId);  break;
      case 'start':    res = await ApiService.startTrip(tripId);    break;
      case 'complete': res = await ApiService.completeTrip(tripId); break;
      default: return;
    }
    if (res['success']) {
      if (action == 'complete') {
        _showSnack('Trip completed! 🎉', isError: false);
        setState(() => _activeTrip = null);
        _loadEarnings();
      } else {
        _showSnack('Status updated', isError: false);
        await _checkActiveTrip();
      }
    } else {
      _showSnack(res['error'], isError: true);
    }
  }

  Future<void> _loadEarnings() async {
    final res = await ApiService.getEarningsSummary();
    if (res['success'] && mounted) {
      setState(() => _earningsRaw = res['data']);
    }
  }

  Future<void> _refreshProfileStatus() async {
    final res = await ApiService.getMe();
    if (res['success']) {
      final data = res['data'];
      final driver = data['driver'];
      if (driver != null) {
        await AuthService.updateApprovalStatus(driver['is_approved'] == true);
        final pic = driver['profile_pic_url'] ?? data['profile_pic'] ?? '';
        if ((pic as String).isNotEmpty) await AuthService.updateProfilePic(pic);
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
      return EarningsData(wallet: AuthService.walletBalance.toStringAsFixed(0), today: '0', week: '0', month: '0', allTime: '0', trips: 0);
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
        backgroundColor: kWhite,
        body: IndexedStack(
          index: _navIndex,
          children: [
            _buildMainMapArea(),
            EarningsScreen(earnings: _earnings, onClose: () => setState(() => _navIndex = 0)),
            _historyTab(),
            _profileTab(),
          ],
        ),
        bottomNavigationBar: _activeTrip == null ? Container(
          decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: kGray2))),
          child: SafeArea(
            child: Row(
              children: [
                for (final tab in [('🏠', 'Home', 0), ('📊', 'Stats', 1), ('📋', 'History', 2), ('👤', 'Profile', 3)])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _navIndex = tab.$3),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _navIndex == tab.$3 ? kOrangeLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text(tab.$1, style: const TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(height: 4),
                            Text(tab.$2, style: GoogleFonts.sora(fontSize: 10, fontWeight: _navIndex == tab.$3 ? FontWeight.w700 : FontWeight.w500, color: _navIndex == tab.$3 ? kOrange : kMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ) : null,
      ),
    );
  }

  Widget _buildMainMapArea() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  MapBackground(isOnline: _isOnline, driverPos: _driverPos),

                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0xF7FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16, right: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 2))]),
                          child: Row(
                            children: [
                              Container(width: 28, height: 28, decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text('K', style: TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 14)))),
                              const SizedBox(width: 7),
                              Text('Ride', style: GoogleFonts.sora(color: kDark, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.5)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(99)),
                                child: Text('DRIVER', style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w700, color: kOrange, letterSpacing: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isOnline ? kSuccess.withOpacity(0.09) : kGray,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: _isOnline ? kSuccess.withOpacity(0.27) : kGray2, width: 1.5),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              _OnlineDot(isOnline: _isOnline),
                              const SizedBox(width: 6),
                              Text(_isOnline ? 'ONLINE' : 'OFFLINE', style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: _isOnline ? kSuccess : kMuted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(color: kOrange.withOpacity(0.27), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AuthService.profilePic.isNotEmpty
                                ? Image.network(AuthService.profilePic, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(AuthService.name.isNotEmpty ? AuthService.name[0].toUpperCase() : 'R', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: kWhite))))
                                : Center(child: Text(AuthService.name.isNotEmpty ? AuthService.name[0].toUpperCase() : 'R', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: kWhite))),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isOnline && _activeTrip == null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 90,
                      left: 16, right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kOrange.withOpacity(0.13)),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            _StatCell(label: 'TRIPS',    value: '${_earnings.trips}'),
                            _StatCell(label: 'EARNINGS', value: '₹${_earnings.today}', showDivider: true),
                            _StatCell(label: 'RATING',   value: '5.0⭐',                     showDivider: true, last: true),
                          ],
                        ),
                      ),
                    ),

                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: Column(
                      children: [
                        for (final icon in [Icons.add, Icons.remove, Icons.my_location])
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: kWhite.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kGray2),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: Center(child: Icon(icon, size: 20, color: kDark)),
                          ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 20,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kGray2),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Text('🗺️ Google Maps ready', style: GoogleFonts.sora(fontSize: 9, color: kMuted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

            if (_activeTrip == null)
              Container(
                decoration: const BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 24, offset: Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kGray2, borderRadius: BorderRadius.circular(99)))),
                    const SizedBox(height: 20),

                    Align(alignment: Alignment.centerLeft, child: Text('$_greeting 👋', style: GoogleFonts.sora(fontSize: 12, color: kMuted, fontWeight: FontWeight.w500))),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(TextSpan(
                        text: '${AuthService.name.split(' ').first} ',
                        style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w800, color: kDark),
                        children: [TextSpan(text: AuthService.name.split(' ').length > 1 ? AuthService.name.split(' ')[1] : '', style: GoogleFonts.sora(color: kOrange))],
                      )),
                    ),
                    const SizedBox(height: 20),

                    _ToggleButton(isOnline: _isOnline, toggling: _toggling, spinCtrl: _spinCtrl, onTap: _handleToggle),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        _QuickAction(icon: '💰', label: 'Earnings', danger: false, onTap: () => setState(() => _navIndex = 1)),
                        const SizedBox(width: 10),
                        _QuickAction(icon: '📋', label: 'History',  danger: false, onTap: () => setState(() => _navIndex = 2)),
                        const SizedBox(width: 10),
                        _QuickAction(icon: '👤', label: 'Profile',  danger: false, onTap: () => setState(() => _navIndex = 3)),
                        const SizedBox(width: 10),
                        _QuickAction(icon: '🆘', label: 'SOS',      danger: true,  onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),

        if (_activeTrip != null)
          ActiveTripPanel(trip: _activeTrip!, onAction: _handleTripAction),

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
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Text('Trip History', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: kDark))),
      Expanded(child: FutureBuilder(
        future: ApiService.getDriverHistory(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: kOrange));
          final res = snap.data as Map<String, dynamic>?;
          if (res == null || !res['success']) return Center(child: Text('Could not load trips', style: GoogleFonts.sora(color: kMuted)));
          final trips = res['data']['trips'] as List;
          if (trips.isEmpty) return const Center(child: Text('No trips yet!'));
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
    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('#${trip['trip_code']}', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: kMuted)),
        _badge(trip['status']),
      ]),
      const SizedBox(height: 6),
      Text(trip['pickup_address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(fontSize: 13, color: kDark)),
      Text('→ ${trip['drop_address'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(fontSize: 13, color: kMuted)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('₹${trip['driver_earnings'] ?? trip['estimated_fare']}',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: kOrange)),
        Text('${trip['distance_km']} km', style: GoogleFonts.sora(fontSize: 12, color: kMuted)),
      ]),
    ]),
  );

  Widget _badge(String? status) {
    Color c = kMuted;
    if (status == 'completed') c = kSuccess;
    if (status == 'cancelled') c = kError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text((status ?? '').toUpperCase(), style: GoogleFonts.sora(fontSize: 10, color: c, fontWeight: FontWeight.w700)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PROFILE TAB
  // ══════════════════════════════════════════════════════════════
  Widget _profileTab() {
    final isApproved = AuthService.isApproved;
    final profilePic = AuthService.profilePic;

    return SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 10),

        Stack(alignment: Alignment.center, children: [
          Container(width: 90, height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: isApproved ? kSuccess : kOrange, width: 3)),
            child: ClipOval(child: profilePic.isNotEmpty
                ? Image.network(profilePic, fit: BoxFit.cover, width: 90, height: 90,
                    errorBuilder: (_, __, ___) => _avatarFallback())
                : _avatarFallback()),
          ),
          Positioned(bottom: 0, right: 0,
            child: Container(padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: kMuted, shape: BoxShape.circle, border: Border.all(color: kWhite, width: 2)),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 12))),
        ]),

        const SizedBox(height: 12),
        Text(AuthService.name, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: kDark)),
        Text('+91 ${AuthService.phone}', style: GoogleFonts.sora(fontSize: 13, color: kMuted)),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isApproved ? kSuccess.withOpacity(0.1) : kOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isApproved ? kSuccess.withOpacity(0.4) : kOrange.withOpacity(0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded, size: 16,
                color: isApproved ? kSuccess : kOrange),
            const SizedBox(width: 6),
            Text(isApproved ? 'Profile Approved ✅' : 'Under verification ⏳',
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isApproved ? kSuccess : kOrange)),
          ]),
        ),

        const SizedBox(height: 30),
        
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.description_rounded, color: kOrange),
          ),
          title: Text('My Documents', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
          trailing: const Icon(Icons.chevron_right_rounded, color: kMuted),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => MyDocumentsScreen(driverId: AuthService.driverId)));
          },
        ),
        
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (r) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kError.withOpacity(0.1), foregroundColor: kError,
              elevation: 0,
            ),
            child: const Text('Log Out'),
          ),
        ),
      ]),
    ));
  }

  Widget _avatarFallback() => Container(color: kGray2, child: const Icon(Icons.person, color: kMuted, size: 40));
}
