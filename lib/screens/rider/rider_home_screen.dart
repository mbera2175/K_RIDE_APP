import 'package:geolocator/geolocator.dart';
import 'package:mappls_gl/mappls_gl.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/rider_socket_service.dart';
import '../../services/place_search_service.dart';
import '../../services/map_service.dart';
import '../auth/role_selection_screen.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:url_launcher/url_launcher.dart';

// ── Constants ──
const kOrange = Color(0xFFFF6B00);
const kOrangeLight = Color(0xFFFFF3E8);
const kOrangeDark = Color(0xFFE55A00);
const kWhite = Color(0xFFFFFFFF);
const kGray = Color(0xFFF6F6F6);
const kDark = Color(0xFF1A1A1A);
const kMuted = Color(0xFF9E9E9E);
const kOrangeBg = Color(0xFFFFF0E6);
const kGreenBg = Color(0xFFF0F7EE);
const kPinkBg = Color(0xFFFFF0F0);
const kEvBg = Color(0xFFF2FAF2);
const kGreenText = Color(0xFF2E7D32);
const kGreenArrow = Color(0xFF4CAF50);
const kPinkArrow = Color(0xFFFF8A80);
const kBorder = Color(0xFFEEEEEE);

// ── Data models ──
class ServiceItem {
  final int id;
  final String name;
  final String icon;
  final String category;
  final String vehicleType;
  final String? tag;
  final Color color;
  final Color accent;
  final bool bikeOnly;
  final bool isEV;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    required this.vehicleType,
    this.tag,
    required this.color,
    required this.accent,
    required this.bikeOnly,
    this.isEV = false,
  });
}

class PaymentMethod {
  final String id;
  final String icon;
  final String label;
  final String sub;

  const PaymentMethod({
    required this.id,
    required this.icon,
    required this.label,
    required this.sub,
  });
}

class PromoItem {
  final String title;
  final String sub;
  final List<Color> gradientColors;

  const PromoItem({
    required this.title,
    required this.sub,
    required this.gradientColors,
  });
}

class PlaceItem {
  final String icon;
  final String label;
  final String sub;

  const PlaceItem({
    required this.icon,
    required this.label,
    required this.sub,
  });
}

// ── Static data ──
const services = [
  ServiceItem(
      id: 1,
      name: 'AC Cab',
      icon: '🚖',
      category: 'ride',
      vehicleType: 'ac_cab',
      tag: 'Comfortable',
      color: kOrangeLight,
      accent: kOrange,
      bikeOnly: false),
  ServiceItem(
      id: 2,
      name: 'Non-AC Cab',
      icon: '🚕',
      category: 'ride',
      vehicleType: 'non_ac_cab',
      tag: 'Budget',
      color: kOrangeLight,
      accent: kOrange,
      bikeOnly: false),
  ServiceItem(
      id: 3,
      name: 'Bike',
      icon: '🏍️',
      category: 'ride',
      vehicleType: 'bike',
      tag: 'Fastest',
      color: kOrangeLight,
      accent: kOrange,
      bikeOnly: false),
  ServiceItem(
      id: 4,
      name: 'Auto',
      icon: '🛺',
      category: 'ride',
      vehicleType: 'auto',
      tag: null,
      color: kOrangeLight,
      accent: kOrange,
      bikeOnly: false),
  ServiceItem(
      id: 5,
      name: 'Toto',
      icon: '🛵',
      category: 'ride',
      vehicleType: 'toto',
      tag: 'EV',
      color: Color(0xFFF0FFF4),
      accent: Color(0xFF2E7D32),
      bikeOnly: false),
  ServiceItem(
      id: 6,
      name: 'Ambulance',
      icon: '🚑',
      category: 'ride',
      vehicleType: 'ambulance',
      tag: 'Emergency',
      color: Color(0xFFFFF0F0),
      accent: Color(0xFFE53935),
      bikeOnly: false),
  ServiceItem(
      id: 10,
      name: 'EV Ride',
      icon: '⚡',
      category: 'ride',
      vehicleType: 'ac_cab',
      tag: 'Eco',
      color: Color(0xFFF0FFF4),
      accent: Color(0xFF2E7D32),
      bikeOnly: false,
      isEV: true),
  ServiceItem(
      id: 7,
      name: 'Food',
      icon: '🍱',
      category: 'delivery',
      vehicleType: 'bike',
      tag: 'Bike only',
      color: kOrangeLight,
      accent: kOrange,
      bikeOnly: true),
  ServiceItem(
      id: 8,
      name: 'Parcel',
      icon: '📦',
      category: 'delivery',
      vehicleType: 'bike',
      tag: 'Bike only',
      color: Color(0xFFF3F0FF),
      accent: Color(0xFF5E35B1),
      bikeOnly: true),
  ServiceItem(
      id: 9,
      name: 'Medicine',
      icon: '💊',
      category: 'delivery',
      vehicleType: 'bike',
      tag: 'Bike only',
      color: Color(0xFFF0F8FF),
      accent: Color(0xFF0277BD),
      bikeOnly: true),
];

const paymentMethods = [
  PaymentMethod(
      id: 'cash', icon: '💵', label: 'Cash', sub: 'Pay driver directly'),
  PaymentMethod(
      id: 'upi', icon: '📱', label: 'UPI', sub: 'GPay, PhonePe, Paytm'),
  PaymentMethod(
      id: 'wallet', icon: '👛', label: 'K Wallet', sub: 'Use wallet balance'),
];

const promos = [
  PromoItem(
      title: 'First ride free!',
      sub: 'Use code KRIDE1',
      gradientColors: [kOrange, kOrangeDark]),
  PromoItem(
      title: 'Food delivery',
      sub: 'Up to 40% off today',
      gradientColors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
  PromoItem(
      title: 'Refer & Earn',
      sub: '₹50 per referral',
      gradientColors: [Color(0xFF5E35B1), Color(0xFF7B1FA2)]),
];

List<PlaceItem> get recentPlaces => [
  PlaceItem(icon: '🏠', label: 'Home', sub: AuthService.homeAddress),
  PlaceItem(icon: '💼', label: 'Office', sub: AuthService.officeAddress),
  PlaceItem(icon: '🛍️', label: 'Select Mall', sub: 'Saket, Delhi'),
  PlaceItem(icon: '✈️', label: 'Airport', sub: 'IGI Terminal 3, Delhi'),
];

List<PlaceItem> get savedLocations => [
  PlaceItem(icon: '🏠', label: 'Home', sub: AuthService.homeAddress),
  PlaceItem(icon: '💼', label: 'Office', sub: AuthService.officeAddress),
];

// ══════════════════════════════════════════════════════════════
//  TOTO ICON
// ══════════════════════════════════════════════════════════════
class TotoIcon extends StatelessWidget {
  final double size;
  const TotoIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TotoPainter()),
    );
  }
}

class _TotoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 128;
    final p = Paint()..style = PaintingStyle.fill;

    p.color = const Color(0xFFFFF7F0);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height),
            Radius.circular(28 * s)),
        p);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFFFFD7B8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(6 * s, 6 * s, 116 * s, 116 * s),
            Radius.circular(24 * s)),
        border);

    final stroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);

    p.color = const Color(0xFF1DB954);
    final roofPath = Path()
      ..moveTo(32 * s, 34 * s)
      ..cubicTo(32 * s, 30 * s, 35 * s, 27 * s, 39 * s, 27 * s)
      ..lineTo(85 * s, 27 * s)
      ..cubicTo(92 * s, 27 * s, 98 * s, 31 * s, 101 * s, 37 * s)
      ..lineTo(104 * s, 43 * s)
      ..lineTo(33 * s, 43 * s)
      ..close();
    canvas.drawPath(roofPath, p);

    p.color = const Color(0xFFDDF5FF);
    final wsPath = Path()
      ..moveTo(28 * s, 44 * s)
      ..cubicTo(28 * s, 38 * s, 33 * s, 33 * s, 39 * s, 33 * s)
      ..lineTo(50 * s, 33 * s)
      ..lineTo(50 * s, 70 * s)
      ..lineTo(28 * s, 70 * s)
      ..close();
    canvas.drawPath(wsPath, p);
    canvas.drawPath(wsPath, stroke2);

    p.color = const Color(0xFF20C05C);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s),
            Radius.circular(8 * s)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s),
            Radius.circular(8 * s)),
        stroke2);

    p.color = const Color(0xFF19A84F);
    final frontPath = Path()
      ..moveTo(24 * s, 58 * s)
      ..cubicTo(24 * s, 53 * s, 28 * s, 49 * s, 33 * s, 49 * s)
      ..lineTo(43 * s, 49 * s)
      ..lineTo(43 * s, 88 * s)
      ..lineTo(31 * s, 88 * s)
      ..cubicTo(27 * s, 88 * s, 24 * s, 85 * s, 24 * s, 81 * s)
      ..close();
    canvas.drawPath(frontPath, p);
    canvas.drawPath(frontPath, stroke2);

    p.color = const Color(0xFF2A2A2A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(48 * s, 57 * s, 18 * s, 12 * s),
            Radius.circular(3 * s)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(70 * s, 57 * s, 18 * s, 12 * s),
            Radius.circular(3 * s)),
        p);

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);
    canvas.drawLine(Offset(46 * s, 34 * s), Offset(46 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(68 * s, 34 * s), Offset(68 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(90 * s, 38 * s), Offset(90 * s, 88 * s), framePaint);

    p.color = const Color(0xFFFFF3B0);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, p);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, stroke2);

    void drawWheel(double cx, double cy, double r) {
      p.color = const Color(0xFF222222);
      canvas.drawCircle(Offset(cx * s, cy * s), r * s, p);
      p.color = const Color(0xFFD9D9D9);
      canvas.drawCircle(Offset(cx * s, cy * s), 5 * s, p);
    }

    drawWheel(42, 95, 10);
    drawWheel(89, 95, 10);
    drawWheel(24, 92, 11);

    p.color = Colors.black.withOpacity(0.08);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(64 * s, 108 * s), width: 68 * s, height: 8 * s),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AutoIcon extends StatelessWidget {
  final double size;
  const AutoIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AutoPainter()),
    );
  }
}

class _AutoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 128;
    final p = Paint()..style = PaintingStyle.fill;

    p.color = const Color(0xFFFFF7F0);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height),
            Radius.circular(28 * s)),
        p);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFFFFD7B8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(6 * s, 6 * s, 116 * s, 116 * s),
            Radius.circular(24 * s)),
        border);

    final stroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);

    p.color = const Color(0xFFFFCC00);
    final roofPath = Path()
      ..moveTo(32 * s, 34 * s)
      ..cubicTo(32 * s, 30 * s, 35 * s, 27 * s, 39 * s, 27 * s)
      ..lineTo(85 * s, 27 * s)
      ..cubicTo(92 * s, 27 * s, 98 * s, 31 * s, 101 * s, 37 * s)
      ..lineTo(104 * s, 43 * s)
      ..lineTo(33 * s, 43 * s)
      ..close();
    canvas.drawPath(roofPath, p);

    p.color = const Color(0xFFDDF5FF);
    final wsPath = Path()
      ..moveTo(28 * s, 44 * s)
      ..cubicTo(28 * s, 38 * s, 33 * s, 33 * s, 39 * s, 33 * s)
      ..lineTo(50 * s, 33 * s)
      ..lineTo(50 * s, 70 * s)
      ..lineTo(28 * s, 70 * s)
      ..close();
    canvas.drawPath(wsPath, p);
    canvas.drawPath(wsPath, stroke2);

    p.color = const Color(0xFFFFCC00);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s),
            Radius.circular(8 * s)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s),
            Radius.circular(8 * s)),
        stroke2);

    p.color = const Color(0xFFFFD600);
    final frontPath = Path()
      ..moveTo(24 * s, 58 * s)
      ..cubicTo(24 * s, 53 * s, 28 * s, 49 * s, 33 * s, 49 * s)
      ..lineTo(43 * s, 49 * s)
      ..lineTo(43 * s, 88 * s)
      ..lineTo(31 * s, 88 * s)
      ..cubicTo(27 * s, 88 * s, 24 * s, 85 * s, 24 * s, 81 * s)
      ..close();
    canvas.drawPath(frontPath, p);
    canvas.drawPath(frontPath, stroke2);

    p.color = const Color(0xFF2A2A2A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(48 * s, 57 * s, 18 * s, 12 * s),
            Radius.circular(3 * s)),
        p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(70 * s, 57 * s, 18 * s, 12 * s),
            Radius.circular(3 * s)),
        p);

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);
    canvas.drawLine(Offset(46 * s, 34 * s), Offset(46 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(68 * s, 34 * s), Offset(68 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(90 * s, 38 * s), Offset(90 * s, 88 * s), framePaint);

    p.color = const Color(0xFFFFF3B0);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, p);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, stroke2);

    void drawWheel(double cx, double cy, double r) {
      p.color = const Color(0xFF222222);
      canvas.drawCircle(Offset(cx * s, cy * s), r * s, p);
      p.color = const Color(0xFFD9D9D9);
      canvas.drawCircle(Offset(cx * s, cy * s), 5 * s, p);
    }

    drawWheel(42, 95, 10);
    drawWheel(89, 95, 10);
    drawWheel(24, 92, 11);

    p.color = Colors.black.withOpacity(0.08);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(64 * s, 108 * s), width: 68 * s, height: 8 * s),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
//  SERVICE ICON
// ══════════════════════════════════════════════════════════════
class ServiceIconWidget extends StatelessWidget {
  final String icon;
  final double size;
  const ServiceIconWidget({super.key, required this.icon, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final cleanIcon = icon.trim().toLowerCase();
    
    if (cleanIcon == '🚖' || cleanIcon == '🚕' || cleanIcon == 'ac_cab' || cleanIcon == 'non_ac_cab') {
      return Image.asset(
        'assets/images/car.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('🚕', style: TextStyle(fontSize: size)),
      );
    }
    if (cleanIcon == '🏍️' || cleanIcon == 'bike') {
      return Image.asset(
        'assets/images/bike.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('🏍️', style: TextStyle(fontSize: size)),
      );
    }
    if (cleanIcon == '🛺' || cleanIcon == 'auto') {
      return Image.asset(
        'assets/images/auto rikswa.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/auto.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, err, st) => Text('🛺', style: TextStyle(fontSize: size)),
          );
        },
      );
    }
    if (cleanIcon == '🛵' || cleanIcon == 'toto') {
      return Image.asset(
        'assets/images/toto.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('🛵', style: TextStyle(fontSize: size)),
      );
    }
    if (cleanIcon == '🚑' || cleanIcon == 'ambulance') {
      return Image.asset(
        'assets/images/ambulance.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('🚑', style: TextStyle(fontSize: size)),
      );
    }
    if (cleanIcon == '🍱' || cleanIcon == 'food') {
      return Image.asset(
        'assets/images/food.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('🍱', style: TextStyle(fontSize: size)),
      );
    }
    if (cleanIcon == '📦' || cleanIcon == 'parcel') {
      return Image.asset(
        'assets/images/parcel.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('📦', style: TextStyle(fontSize: size)),
      );
    }
    if (cleanIcon == '💊' || cleanIcon == 'medicine') {
      return Image.asset(
        'assets/images/medicine.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text('💊', style: TextStyle(fontSize: size)),
      );
    }

    return Text(icon,
        style: TextStyle(
            fontSize: size,
            fontFamily: 'Roboto',
            fontFamilyFallback: const [
              'Noto Color Emoji',
              'Apple Color Emoji',
              'Segoe UI Emoji'
            ]));
  }
}

// ══════════════════════════════════════════════════════════════
//  SERVICE CARD
// ══════════════════════════════════════════════════════════════
class ServiceCard extends StatefulWidget {
  final ServiceItem service;
  final VoidCallback onTap;
  const ServiceCard({super.key, required this.service, required this.onTap});

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.service.color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: widget.service.accent.withOpacity(0.13),
                          blurRadius: 14,
                          offset: const Offset(0, 4))
                    ],
                    border: Border.all(
                        color: widget.service.accent.withOpacity(0.13),
                        width: 1.5),
                  ),
                  child: Center(
                      child: ServiceIconWidget(
                          icon: widget.service.icon, size: 30)),
                ),
                if (widget.service.tag != null)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.service.accent,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                              color: widget.service.accent.withOpacity(0.33),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text(widget.service.tag!,
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: kWhite)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.service.name,
              style: const TextStyle(
                  fontSize: 11.0, fontWeight: FontWeight.w600, color: kDark),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PROMO CARD
// ══════════════════════════════════════════════════════════════
class PromoCard extends StatelessWidget {
  final PromoItem promo;
  const PromoCard({super.key, required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 100,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
            colors: promo.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20, child: _circle(90, 0.12)),
          Positioned(right: 20, bottom: -30, child: _circle(70, 0.08)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(promo.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kWhite)),
                const SizedBox(height: 4),
                Text(promo.sub,
                    style: TextStyle(
                        fontSize: 12, color: kWhite.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
      );
}

// ══════════════════════════════════════════════════════════════
//  LOCATION MODAL
// ══════════════════════════════════════════════════════════════
class LocationModal extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;
  const LocationModal(
      {super.key,
      required this.current,
      required this.onSelect,
      required this.onClose});

  @override
  State<LocationModal> createState() => _LocationModalState();
}

class _LocationModalState extends State<LocationModal> {
  final _controller = TextEditingController();
  bool _locating = false;

  void _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        widget.onSelect('Current Location');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      try {
        final placemarks = await geo.placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final String name = pm.name ?? '';
          final String subLocality = pm.subLocality ?? '';
          final String locality = pm.locality ?? '';
          final String street = pm.street ?? '';
          
          String address = "";
          if (street.isNotEmpty && !street.contains("+") && !street.contains("Unnamed")) {
            address += "$street, ";
          } else if (name.isNotEmpty && !name.contains("+") && !name.contains("Unnamed")) {
            address += "$name, ";
          }
          if (subLocality.isNotEmpty) address += "$subLocality, ";
          if (locality.isNotEmpty) address += locality;
          
          final finalAddress = address.trim().endsWith(",") 
              ? address.trim().substring(0, address.trim().length - 1) 
              : address.trim();
          widget.onSelect(finalAddress.isEmpty ? 'Current Location' : finalAddress);
        } else {
          widget.onSelect('Current Location');
        }
      } catch (_) {
        widget.onSelect('Current Location');
      }
    } catch (_) {
      widget.onSelect('Current Location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 40),
            decoration: const BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: const Color(0xFFDDDDDD),
                              borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Set pickup location',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kDark)),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: kGray,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.close,
                                size: 14, color: kDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                        color: kGray,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFEEEEEE), width: 1.5)),
                    child: Row(
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Type your location...',
                                hintStyle: TextStyle(
                                    color: Color(0xFFBDBDBD), fontSize: 14)),
                            style: const TextStyle(fontSize: 14, color: kDark),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => widget.onSelect(_controller.text),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: kOrange,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('Set',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kWhite)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _useCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: kOrangeLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: kOrange.withOpacity(0.2), width: 1.5)),
                      child: Row(
                        children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: kOrange,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Center(
                                  child: Text(_locating ? '⏳' : '🎯',
                                      style: const TextStyle(fontSize: 18)))),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  _locating
                                      ? 'Detecting location...'
                                      : 'Use current location',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kOrange)),
                              const Text('Uses GPS to find you',
                                  style:
                                      TextStyle(fontSize: 12, color: kMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('SAVED PLACES',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kMuted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  ...savedLocations.map((loc) {
                    final full = '${loc.label}, ${loc.sub}';
                    final selected = widget.current == full;
                    return GestureDetector(
                      onTap: () => widget.onSelect(full),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                            color: selected ? kOrangeLight : kGray,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: kWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.07),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2))
                                    ]),
                                child: Center(
                                    child: Text(loc.icon,
                                        style: const TextStyle(fontSize: 18)))),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.label,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kDark)),
                                  Text(loc.sub,
                                      style: const TextStyle(
                                          fontSize: 12, color: kMuted)),
                                ],
                              ),
                            ),
                            if (selected)
                              const Text('✓',
                                  style:
                                      TextStyle(color: kOrange, fontSize: 16)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PAYMENT MODAL
// ══════════════════════════════════════════════════════════════
class PaymentModal extends StatelessWidget {
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelect;
  final VoidCallback onClose;
  const PaymentModal(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 40),
            decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFDDDDDD),
                            borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment method',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kDark)),
                    GestureDetector(
                        onTap: onClose,
                        child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: kGray,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.close, size: 14))),
                  ],
                ),
                const SizedBox(height: 20),
                ...paymentMethods.map((pm) {
                  final sel = selected.id == pm.id;
                  return GestureDetector(
                    onTap: () {
                      onSelect(pm);
                      onClose();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? kOrangeLight : kGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: sel ? kOrange : Colors.transparent,
                            width: 2),
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
                                        color: Colors.black.withOpacity(0.07),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: Center(
                                  child: Text(pm.icon,
                                      style: const TextStyle(fontSize: 22)))),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(pm.label,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: kDark)),
                                Text(pm.sub,
                                    style: const TextStyle(
                                        fontSize: 12, color: kMuted)),
                              ])),
                          if (sel)
                            const Text('✓',
                                style: TextStyle(color: kOrange, fontSize: 20)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SEE ALL MODAL
// ══════════════════════════════════════════════════════════════
class SeeAllModal extends StatelessWidget {
  final String title;
  final List<ServiceItem> items;
  final ValueChanged<ServiceItem> onSelect;
  final VoidCallback onClose;
  const SeeAllModal(
      {super.key,
      required this.title,
      required this.items,
      required this.onSelect,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isRide = title.toLowerCase() == 'ride';
    ServiceItem? evRide;
    try {
      if (isRide) {
        evRide = items.firstWhere((s) => s.id == 10);
      }
    } catch (_) {}

    final gridItems = isRide && evRide != null
        ? items.where((s) => s.id != 10).toList()
        : items;

    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 40),
            decoration: const BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('All $title services',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: kDark)),
                    GestureDetector(
                        onTap: onClose,
                        child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: kGray,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.close, size: 14))),
                  ],
                ),
                const SizedBox(height: 20),
                if (isRide && evRide != null) ...[
                  GestureDetector(
                    onTap: () {
                      onSelect(evRide!);
                      onClose();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF81C784).withOpacity(0.5),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32).withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF2E7D32).withOpacity(0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Text('⚡', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'EV Ride',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: const Text(
                                        'Eco',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'one step closer to the better world',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF388E3C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF2E7D32), size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.9),
                    itemCount: gridItems.length,
                    itemBuilder: (_, i) {
                      final s = gridItems[i];
                      return GestureDetector(
                        onTap: () {
                          onSelect(s);
                          onClose();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                      color: s.color,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: s.accent.withOpacity(0.13),
                                          width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                            color: s.accent.withOpacity(0.13),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4))
                                      ]),
                                  child: Center(
                                      child: ServiceIconWidget(
                                          icon: s.icon, size: 30))),
                              if (s.tag != null)
                                Positioned(
                                    top: -6,
                                    right: -6,
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: s.accent,
                                            borderRadius:
                                                BorderRadius.circular(99)),
                                        child: Text(s.tag!,
                                            style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w700,
                                                color: kWhite)))),
                            ]),
                            const SizedBox(height: 8),
                            Text(s.name,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kDark),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  BOOKING SUCCESS SCREEN
// ══════════════════════════════════════════════════════════════
class BookingSuccessScreen extends StatefulWidget {
  final ServiceItem service;
  final String destination;
  final PaymentMethod payment;
  final VoidCallback onDone;
  const BookingSuccessScreen(
      {super.key,
      required this.service,
      required this.destination,
      required this.payment,
      required this.onDone});

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  int _countdown = 3;
  Timer? _timer;
  late AnimationController _pingController;
  late Animation<double> _pingAnim;

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _pingAnim = Tween(begin: 1.0, end: 2.0).animate(_pingController);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kWhite,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pingAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pingAnim.value,
                  child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: kOrange.withOpacity(0.3), width: 3))),
                ),
              ),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: kOrangeLight),
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: kOrange),
                    child: const Center(
                        child: Text('✓',
                            style: TextStyle(fontSize: 40, color: kWhite))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Booking Confirmed!',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: kDark),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Your ${widget.service.name} is being assigned',
              style: const TextStyle(fontSize: 14, color: kMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: kGray, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: widget.service.color,
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(
                            child: ServiceIconWidget(
                                icon: widget.service.icon, size: 26))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(widget.service.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kDark)),
                          const Text('Driver being assigned...',
                              style: TextStyle(fontSize: 12, color: kMuted)),
                        ])),
                    Text('₹89',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: widget.service.accent)),
                  ],
                ),
                Divider(height: 32, color: Colors.grey.shade200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DESTINATION',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(widget.destination,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: kDark,
                                  fontWeight: FontWeight.w600)),
                        ]),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('PAYMENT',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('${widget.payment.icon} ${widget.payment.label}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: kDark,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Going to tracking in ${_countdown}s...',
              style: const TextStyle(fontSize: 13, color: kMuted)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: kOrange.withOpacity(0.27)),
              child: const Text('Track my ride →',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TRIP CHAT SCREEN  ← TOP-LEVEL (was nested inside _RiderHomeScreenState)
// ══════════════════════════════════════════════════════════════
class TripChatScreen extends StatefulWidget {
  final int tripId;
  final String driverName;
  final String driverPhone;
  final String driverPhotoUrl;
  final VoidCallback onClose;
  const TripChatScreen(
      {super.key,
      required this.tripId,
      this.driverName = '',
      this.driverPhone = '',
      this.driverPhotoUrl = '',
      required this.onClose});

  @override
  State<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends State<TripChatScreen> {
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
      if (mounted) _loadData(silent: true);
    });
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isMe(Map<String, dynamic> message) {
    final myId = AuthService.userId;
    final senderId = (message['sender_id'] as num?)?.toInt();
    return myId != 0 && senderId == myId;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
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
      final res =
          await ApiService.sendChatMessage(widget.tripId, type, text, quickKey);
      if (res['success'] == true) {
        _msgCtrl.clear();
        await _loadData(silent: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat with Driver',
                style: TextStyle(
                    color: Color(0xFF1A1A2E), fontWeight: FontWeight.w800)),
            if (widget.driverName.isNotEmpty)
              Text(widget.driverName,
                  style: const TextStyle(
                      color: Color(0xFF6B6B6B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        titleSpacing: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
            onPressed: widget.onClose),
      ),
      body: Column(children: [
        if (widget.driverName.isNotEmpty || widget.driverPhone.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFE0CC)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFE8D6),
                  backgroundImage: widget.driverPhotoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(widget.driverPhotoUrl)
                      : null,
                  child: widget.driverPhotoUrl.isEmpty
                      ? Text(
                          widget.driverName.isNotEmpty
                              ? widget.driverName.substring(0, 1).toUpperCase()
                              : 'D',
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName.isNotEmpty
                            ? widget.driverName
                            : 'Driver accepted your trip',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.driverPhone.isNotEmpty
                            ? widget.driverPhone
                            : 'Phone number unavailable',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.driverPhone.isNotEmpty)
                  IconButton(
                    onPressed: () async {
                      final uri = Uri.parse('tel:${widget.driverPhone}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.call, color: Color(0xFFFF6B35)),
                  ),
              ],
            ),
          ),
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
                  onTap: () => _sendMessage(label,
                      type: 'quick', quickKey: q['key']),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFF6B35).withOpacity(0.5)),
                    ),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFFFF6B35))),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) {
                    final m = _messages[i];
                    final isMe = _isMe(m);
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m['message_text'] ?? '',
                            style: TextStyle(
                                fontSize: 14,
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E))),
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
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_msgCtrl.text.trim().isNotEmpty && !_sending)
                  _sendMessage(_msgCtrl.text.trim());
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35), shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TRIP RECEIPT SCREEN  ← TOP-LEVEL (was nested inside _RiderHomeScreenState)
// ══════════════════════════════════════════════════════════════
class TripReceiptScreen extends StatefulWidget {
  final int tripId;
  final VoidCallback onClose;
  const TripReceiptScreen(
      {super.key, required this.tripId, required this.onClose});

  @override
  State<TripReceiptScreen> createState() => _TripReceiptScreenState();
}

class _TripReceiptScreenState extends State<TripReceiptScreen> {
  static const _quickComments = [
    'Great driver',
    'Clean vehicle',
    'Safe driving',
    'Friendly service',
    'On time pickup',
  ];

  Map<String, dynamic>? _receipt;
  bool _loading = true;
  bool _submittingRating = false;
  bool _rated = false;
  int _rating = 5;
  final _ratingCommentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    try {
      final res = await ApiService.getTripReceipt(widget.tripId);
      if (res['success'] == true) {
        setState(() {
          _receipt = Map<String, dynamic>.from(res['data'] ?? {});
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitRating() async {
    if (_submittingRating || _rated) return;
    setState(() => _submittingRating = true);
    final res = await ApiService.rateDriver(
        widget.tripId, _rating, _ratingCommentCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _submittingRating = false;
      _rated = res['success'] == true || res['status'] == 400;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['success'] == true
          ? 'Thanks for rating your driver.'
          : (res['error'] ?? 'Rating skipped.')),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
    if (res['success'] == true || res['status'] == 400) {
      widget.onClose();
    }
  }

  @override
  void dispose() {
    _ratingCommentCtrl.dispose();
    super.dispose();
  }

  Widget _receiptRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? const Color(0xFF1A1A2E))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Trip Receipt',
            style: TextStyle(
                color: Color(0xFF1A1A2E), fontWeight: FontWeight.w800)),
        leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A2E)),
            onPressed: widget.onClose),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _receipt == null
              ? const Center(child: Text('Receipt not available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                          color: Color(0xFFF0FFF4), shape: BoxShape.circle),
                      child: const Center(
                          child: Text('✅', style: TextStyle(fontSize: 36))),
                    ),
                    const SizedBox(height: 12),
                    const Text('Trip Completed!',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E))),
                    Text(_receipt!['trip_code'] ?? '',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    _receiptRow('📍 Pickup', _receipt!['pickup_address'] ?? ''),
                    _receiptRow('🏁 Drop', _receipt!['drop_address'] ?? ''),
                    const Divider(height: 24),
                    _receiptRow(
                        'Distance', '${_receipt!['distance_km'] ?? 0} km'),
                    _receiptRow(
                        'Duration', '${_receipt!['duration_min'] ?? 0} min'),
                    _receiptRow(
                        'Vehicle',
                        _receipt!['vehicle_type']
                                ?.toString()
                                .replaceAll('_', ' ')
                                .toUpperCase() ??
                            ''),
                    const Divider(height: 24),
                    _receiptRow('Base Fare', '₹${_receipt!['base_fare'] ?? 0}'),
                    if ((_receipt!['surge_multiplier'] ?? 1.0) > 1.0)
                      _receiptRow(
                          'Surge (${_receipt!['surge_multiplier']}x)', ''),
                    if ((_receipt!['bonus_amount'] ?? 0) > 0)
                      _receiptRow(
                          'Bonus Added', '+₹${_receipt!['bonus_amount']}'),
                    if ((_receipt!['promo_discount'] ?? 0) > 0)
                      _receiptRow('Promo (${_receipt!['promo_code']})',
                          '-₹${_receipt!['promo_discount']}',
                          color: Colors.green),
                    if ((_receipt!['kcoin_discount'] ?? 0) > 0)
                      _receiptRow('K Coins Used (${_receipt!['kcoin_used']})',
                          '-₹${_receipt!['kcoin_discount']}',
                          color: Colors.green),
                    const Divider(height: 24),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A2E))),
                          Text('₹${_receipt!['actual_fare'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF6B35))),
                        ]),
                    const SizedBox(height: 8),
                    _receiptRow(
                        'Payment Method',
                        _receipt!['payment_method']?.toString().toUpperCase() ??
                            ''),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFFFF3E0),
                            child: Text(
                                _receipt!['driver']?['name']
                                        ?.toString()
                                        .substring(0, 1) ??
                                    'D',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFF6B35)))),
                        const SizedBox(width: 12),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_receipt!['driver']?['name'] ?? 'Driver',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  _receipt!['driver']?['vehicle_type']
                                          ?.toString()
                                          .replaceAll('_', ' ') ??
                                      '',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            ]),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFD180))),
                      child: Column(children: [
                        const Text('Rate your driver',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E))),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (i) => IconButton(
                              onPressed: _rated
                                  ? null
                                  : () => setState(() => _rating = i + 1),
                              icon: Icon(
                                i < _rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFFF6B35),
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: _quickComments.map((text) {
                            final selected = _ratingCommentCtrl.text == text;
                            return ChoiceChip(
                              label: Text(text),
                              selected: selected,
                              selectedColor: const Color(0xFFFFE0B2),
                              onSelected: _rated
                                  ? null
                                  : (_) => setState(() {
                                        _ratingCommentCtrl.text = text;
                                      }),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selected
                                    ? const Color(0xFFFF6B35)
                                    : const Color(0xFF1A1A2E),
                              ),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFFFF6B35)
                                    : const Color(0xFFE0E0E0),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ratingCommentCtrl,
                          enabled: !_rated,
                          minLines: 2,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Optional comment',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submittingRating ? null : _submitRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                              _submittingRating
                                  ? 'Submitting...'
                                  : 'Submit Review',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        )),
                  ]),
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  WHERE TO SCREEN
// ══════════════════════════════════════════════════════════════
class WhereToScreen extends StatefulWidget {
  final ServiceItem service;
  final String prefilledDest;
  final VoidCallback onBack;
  final int? activeTripId;
  final bool genericMode;
  const WhereToScreen(
      {super.key,
      required this.service,
      required this.prefilledDest,
      required this.onBack,
      this.activeTripId,
      this.genericMode = false});

  @override
  State<WhereToScreen> createState() => _WhereToScreenState();
}

class _WhereToScreenState extends State<WhereToScreen>
    with WidgetsBindingObserver {
  Future<bool> handleBackPress() async {
    final status = _normalizeTripStatus(_tripStatus);
    if (_step == 'tracking' &&
        (status == 'accepted' || status == 'arrived' || status == 'started')) {
      return false; // block pop
    }
    if (_searching) {
      await _cancelCurrentRide(closeAfterCancel: true);
      return true;
    }
    widget.onBack();
    return true;
  }

  final _pickupCtrl = TextEditingController(text: 'Fetching current location...');
  late TextEditingController _destCtrl;
  String _step = 'input';
  PaymentMethod _paymentMethod = paymentMethods[0];
  bool _booked = false;
  bool _showPaymentModal = false;
  late String _selectedVehicleType;
  double _bonusAmount = 0.0;
  double _pickupLat = 22.5726;
  double _pickupLng = 88.3639;
  double _dropLat = 22.5850;
  double _dropLng = 88.3950;
  bool _useKCoins = false;
  int? _tripId;
  bool _searching = false;
  bool _socketDisconnected = false;
  bool _isChatScreenOpen = false;
  Timer? _searchPollTimer;
  Timer? _trackingPollTimer;
  double _estimatedFare = 0.0;
  double _estimatedDistance = 0.0;
  int _estimatedDuration = 0;
  bool _fareLoading = false;

  List<dynamic> _activePromos = [];
  String? _appliedPromoCode;
  double _promoDiscount = 0.0;
  bool _isManualPromoApplied = false;

  // Active Tracking state
  String _tripStatus = 'requested';
  Map<String, dynamic>? _assignedDriver;
  String? _otpCode;
  double? _driverLat;
  double? _driverLng;
  MapplsMapController? _mapController;
  Symbol? _driverSymbol;
  final Set<String> _registeredIcons = {};
  final List<Symbol> _driverSymbols = [];
  Timer? _searchingTimer;
  int _searchSecondsLeft = 150;
  int _initialSearchDuration = 150;

  List<MapplsPlaceSuggestion> _suggestions = [];
  bool _suggestionsLoading = false;
  Timer? _debounceTimer;
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  List<PlaceItem> get _quickDests => [
    PlaceItem(icon: '🏠', label: 'Home', sub: AuthService.homeAddress),
    PlaceItem(icon: '💼', label: 'Office', sub: AuthService.officeAddress),
  ];

  String _normalizeTripStatus(dynamic status) {
    var text = (status ?? 'requested').toString().trim().toLowerCase();
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
    return text.isEmpty ? 'requested' : text;
  }

  String? _readTripOtp(Map<String, dynamic>? data) {
    if (data == null) return null;
    for (final key in ['otp_code', 'otp', 'trip_otp', 'otpCode', 'ride_otp']) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  bool get _shouldExpectTripOtp {
    final status = _normalizeTripStatus(_tripStatus);
    return status == 'driver_assigned' ||
        status == 'accepted' ||
        status == 'arrived';
  }

  bool get _shouldShowTripOtp =>
      _shouldExpectTripOtp && _otpCode != null && _otpCode!.trim().isNotEmpty;

  Future<void> _loadActivePromos() async {
    try {
      final res = await ApiService.getActivePromos();
      if (res['success'] == true && res['promos'] != null) {
        setState(() {
          _activePromos = res['promos'] as List<dynamic>;
        });
        _applyBestAutoPromo();
      }
    } catch (e) {
      debugPrint('Error loading active promos: $e');
    }
  }

  void _revalidateAppliedPromo() {
    if (!_isManualPromoApplied || _appliedPromoCode == null) {
      _applyBestAutoPromo();
      return;
    }
    
    final match = _activePromos.firstWhere(
      (p) => (p['code'] as String).toUpperCase() == _appliedPromoCode!.toUpperCase(),
      orElse: () => null,
    );
    
    if (match == null) {
      setState(() {
        _appliedPromoCode = null;
        _promoDiscount = 0.0;
        _isManualPromoApplied = false;
      });
      _applyBestAutoPromo();
      return;
    }
    
    final minFare = (match['min_fare'] as num?)?.toDouble() ?? 0.0;
    final vType = match['vehicle_type'] as String?;
    
    if (_estimatedFare < minFare || 
        (vType != null && vType != 'All' && vType.toLowerCase() != _selectedVehicleType.toLowerCase())) {
      setState(() {
        _appliedPromoCode = null;
        _promoDiscount = 0.0;
        _isManualPromoApplied = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promo code $_appliedPromoCode is no longer applicable.'))
      );
      _applyBestAutoPromo();
    } else {
      double disc = 0.0;
      final val = (match['discount_value'] as num?)?.toDouble() ?? 0.0;
      if (match['discount_type'] == 'flat') {
        disc = val;
      } else if (match['discount_type'] == 'percentage') {
        disc = _estimatedFare * val / 100.0;
      }
      setState(() {
        _promoDiscount = disc;
      });
    }
  }

  void _applyBestAutoPromo() {
    if (_isManualPromoApplied) return;
    
    double bestDiscount = 0.0;
    String? bestCode;
    
    for (var p in _activePromos) {
      if (p['is_auto_apply'] != true) continue;
      
      // Check min fare
      final minFare = (p['min_fare'] as num?)?.toDouble() ?? 0.0;
      if (_estimatedFare < minFare) continue;
      
      // Check vehicle type
      final vType = p['vehicle_type'] as String?;
      if (vType != null && vType != 'All' && vType.toLowerCase() != _selectedVehicleType.toLowerCase()) {
        continue;
      }
      
      // Calculate discount
      double disc = 0.0;
      final val = (p['discount_value'] as num?)?.toDouble() ?? 0.0;
      if (p['discount_type'] == 'flat') {
        disc = val;
      } else if (p['discount_type'] == 'percentage') {
        disc = _estimatedFare * val / 100.0;
      }
      
      if (disc > bestDiscount) {
        bestDiscount = disc;
        bestCode = p['code'] as String?;
      }
    }
    
    setState(() {
      _appliedPromoCode = bestCode;
      _promoDiscount = bestDiscount;
    });
  }

  void _applyManualPromo(String code) {
    final searchCode = code.trim().toUpperCase();
    if (searchCode.isEmpty) {
      setState(() {
        _appliedPromoCode = null;
        _promoDiscount = 0.0;
        _isManualPromoApplied = false;
      });
      _applyBestAutoPromo(); // fallback to auto apply
      return;
    }
    
    // Find the promo in the active promos list
    final match = _activePromos.firstWhere(
      (p) => (p['code'] as String).toUpperCase() == searchCode,
      orElse: () => null,
    );
    
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or inactive promo code.'))
      );
      return;
    }
    
    // Check constraints
    final minFare = (match['min_fare'] as num?)?.toDouble() ?? 0.0;
    if (_estimatedFare < minFare) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum fare of ₹${minFare.toStringAsFixed(0)} required for this promo.'))
      );
      return;
    }
    
    final vType = match['vehicle_type'] as String?;
    if (vType != null && vType != 'All' && vType.toLowerCase() != _selectedVehicleType.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This promo is only valid for $vType vehicles.'))
      );
      return;
    }
    
    // Calculate discount
    double disc = 0.0;
    final val = (match['discount_value'] as num?)?.toDouble() ?? 0.0;
    if (match['discount_type'] == 'flat') {
      disc = val;
    } else if (match['discount_type'] == 'percentage') {
      disc = _estimatedFare * val / 100.0;
    }
    
    setState(() {
      _appliedPromoCode = match['code'] as String?;
      _promoDiscount = disc;
      _isManualPromoApplied = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Promo code applied successfully!'))
    );
  }

  void _showPromoCodeModal() {
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + (MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 20),
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Apply Promo Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Enter Coupon Code',
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: kOrange),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          final code = textCtrl.text.trim().toUpperCase();
                          if (code.isNotEmpty) {
                            _applyManualPromo(code);
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_appliedPromoCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Applied: $_appliedPromoCode (-₹${_promoDiscount.toStringAsFixed(2)})',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _appliedPromoCode = null;
                                _promoDiscount = 0.0;
                                _isManualPromoApplied = false;
                              });
                              _applyBestAutoPromo();
                              setModalState(() {});
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Available Offers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_activePromos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No coupon codes available at the moment.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _activePromos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final promo = _activePromos[index];
                          final code = promo['code'] as String? ?? '';
                          final desc = promo['description'] as String? ?? '';
                          final disp = promo['discount_display'] as String? ?? '';
                          final minFare = (promo['min_fare'] as num?)?.toDouble() ?? 0.0;
                          final isApplicable = _estimatedFare >= minFare;
                          final isCurrent = _appliedPromoCode == code;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCurrent ? const Color(0xFFFFF3E0) : kGray,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent ? kOrange : const Color(0xFFEEEEEE),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: kOrange.withOpacity(0.1),
                                              border: Border.all(color: kOrange),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              code,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: kOrange,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Save $disp',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: kDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        desc,
                                        style: const TextStyle(fontSize: 11, color: kMuted),
                                      ),
                                      if (minFare > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Min Fare: ₹${minFare.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isApplicable ? kMuted : Colors.red,
                                            fontWeight: isApplicable ? FontWeight.normal : FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: isApplicable
                                      ? () {
                                          _applyManualPromo(code);
                                          Navigator.pop(ctx);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrent ? Colors.green : kDark,
                                    disabledBackgroundColor: Colors.grey[300],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Text(
                                    isCurrent ? 'Applied' : 'Apply',
                                    style: TextStyle(
                                      color: isApplicable ? Colors.white : Colors.grey[600],
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadActivePromos();
    WidgetsBinding.instance.addObserver(this);
    _destCtrl = TextEditingController(text: widget.prefilledDest);
    
    _destCtrl.addListener(_onSearchTextChanged);
    _pickupCtrl.addListener(_onSearchTextChanged);
    
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        if (_pickupCtrl.text == 'Fetching current location...' || _pickupCtrl.text == 'Current Location') {
          _pickupCtrl.clear();
        }
      } else {
        if (_pickupCtrl.text.isEmpty) {
          _pickupCtrl.text = 'Current Location';
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_pickupFocus.hasFocus && !_destFocus.hasFocus) {
            setState(() => _suggestions = []);
          }
        });
      }
    });
    _destFocus.addListener(() {
      if (!_destFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_pickupFocus.hasFocus && !_destFocus.hasFocus) {
            setState(() => _suggestions = []);
          }
        });
      }
    });
    final initialVehicle = widget.service.vehicleType;
    _selectedVehicleType = ['ac_cab', 'non_ac_cab', 'bike', 'auto', 'toto']
            .contains(initialVehicle)
        ? initialVehicle
        : 'ac_cab';

    if (widget.activeTripId != null) {
      _tripId = widget.activeTripId;
      _booked = true;
      _searching = false;
      _step = 'tracking';
      _loadActiveTripDetails();
      _startTrackingPolling();
    } else {
      _getLocation();
    }

    final riderId = AuthService.riderId;
    final token = AuthService.token;
    if (riderId != null && token != null) {
      _connectSocket(riderId, token);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        _tripId != null &&
        (_searching || _step == 'tracking')) {
      _loadActiveTripDetails();
    }
  }

  void _startSearchPolling() {
    _startSearchingTimer();
    _searchPollTimer?.cancel();
    _searchPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || !_searching || _tripId == null) return;
      try {
        final res = await ApiService.getActiveTrip();
        if (res['success'] == true && res['data']?['active_trip'] != null) {
          final trip = res['data']['active_trip'];
          final status = _normalizeTripStatus(trip['status']);
          if (status == 'requested') return;

          // If trip is already completed (e.g. driver completed while app was polling),
          // navigate straight to the receipt & rating screen.
          if (status == 'completed') {
            _searchPollTimer?.cancel();
            RiderSocketService.disconnect();
            final completedTripId = (trip['id'] as num?)?.toInt() ?? _tripId;
            if (!mounted || completedTripId == null) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TripReceiptScreen(
                  tripId: completedTripId,
                  onClose: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ),
            );
            return;
          }

          final driver = trip['driver'] as Map<String, dynamic>?;
          final dLat = (driver?['current_lat'] as num?)?.toDouble();
          final dLng = (driver?['current_lng'] as num?)?.toDouble();

          if (!mounted) return;
          setState(() {
            _tripId = (trip['id'] as num?)?.toInt() ?? _tripId;
            _booked = true;
            _searching = false;
            _step = 'tracking';
            _tripStatus = status;
            _otpCode = _readTripOtp(trip);
            _assignedDriver = driver;
            _driverLat = dLat;
            _driverLng = dLng;
          });

          if (dLat != null && dLng != null) {
            _updateDriverMarkerAnimated(dLat, dLng);
            _drawRiderTripRoute();
          }
          _searchPollTimer?.cancel();
          _startTrackingPolling();
        }
      } catch (e) {
        debugPrint('Search poll error: $e');
      }
    });
  }

  void _startSearchingTimer({int seconds = 150}) {
    _searchingTimer?.cancel();
    _initialSearchDuration = seconds;
    _searchSecondsLeft = seconds;
    _searchingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_searching) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_searchSecondsLeft > 0) {
          _searchSecondsLeft--;
        } else {
          timer.cancel();
          _stopSearchPolling();
          setState(() {
            _booked = false;
            _searching = false;
            _step = 'input';
            _tripId = null;
            _otpCode = null;
            _assignedDriver = null;
            _driverLat = null;
            _driverLng = null;
            _bonusAmount = 0;
          });
          _showNoDriverDialog();
        }
      });
    });
  }

  void _stopSearchPolling() {
    _searchPollTimer?.cancel();
    _searchPollTimer = null;
    _searchingTimer?.cancel();
    _searchingTimer = null;
  }

  void _startTrackingPolling() {
    _trackingPollTimer?.cancel();
    _trackingPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _step != 'tracking' || _tripId == null) return;
      try {
        final res = await ApiService.getActiveTrip();
        if (res['success'] == true) {
          final trip = res['data']?['active_trip'];
          if (trip == null) {
            _trackingPollTimer?.cancel();
            await _handleFinishedTrip();
          } else {
            final status = _normalizeTripStatus(trip['status']);
            final driver = trip['driver'] as Map<String, dynamic>?;
            final dLat = (driver?['current_lat'] as num?)?.toDouble();
            final dLng = (driver?['current_lng'] as num?)?.toDouble();
            final otpCode = _readTripOtp(trip);
            if (mounted) {
              final oldStatus = _normalizeTripStatus(_tripStatus);
              setState(() {
                _tripStatus = status;
                if (status == 'started' || status == 'completed' || status == 'cancelled') {
                  _otpCode = null;
                } else if (otpCode != null) {
                  _otpCode = otpCode;
                }
                if (driver != null) {
                  _assignedDriver = driver;
                }
                if (dLat != null && dLng != null) {
                  _driverLat = dLat;
                  _driverLng = dLng;
                }
              });
              if (dLat != null && dLng != null) {
                _updateDriverMarkerAnimated(dLat, dLng);
                _drawRiderTripRoute();
              }

              if (oldStatus != 'started' && status == 'started') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Trip started! Have a safe journey. 🚗"),
                    backgroundColor: Colors.green));
                _openNavigation(_dropLat, _dropLng);
              } else if (oldStatus != 'arrived' && status == 'arrived') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Driver has arrived at pickup location! 📍"),
                    backgroundColor: kOrange));
              }

              if (status == 'completed') {
                _trackingPollTimer?.cancel();
                await _handleFinishedTrip();
                return;
              }

              if (status == 'cancelled') {
                _trackingPollTimer?.cancel();
                RiderSocketService.disconnect();
                widget.onBack();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip was cancelled')),
                );
                return;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Tracking poll error: $e');
      }
    });
  }

  void _stopTrackingPolling() {
    _trackingPollTimer?.cancel();
    _trackingPollTimer = null;
  }

  Future<void> _handleFinishedTrip() async {
    if (_tripId == null) return;
    try {
      final res = await ApiService.getTripReceipt(_tripId!);
      if (res['success'] == true) {
        RiderSocketService.disconnect();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TripReceiptScreen(
              tripId: _tripId!,
              onClose: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        );
      } else {
        RiderSocketService.disconnect();
        if (!mounted) return;
        widget.onBack();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip was cancelled')),
        );
      }
    } catch (e) {
      RiderSocketService.disconnect();
      if (mounted) widget.onBack();
    }
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _pickupCtrl.text = 'Current Location';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
      });
      try {
        final placemarks = await geo.placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final String name = pm.name ?? '';
          final String subLocality = pm.subLocality ?? '';
          final String locality = pm.locality ?? '';
          final String street = pm.street ?? '';
          
          String address = "";
          if (street.isNotEmpty && !street.contains("+") && !street.contains("Unnamed")) {
            address += "$street, ";
          } else if (name.isNotEmpty && !name.contains("+") && !name.contains("Unnamed")) {
            address += "$name, ";
          }
          if (subLocality.isNotEmpty) address += "$subLocality, ";
          if (locality.isNotEmpty) address += locality;
          
          if (address.isEmpty) {
            address = pm.subAdministrativeArea ?? pm.administrativeArea ?? "Current Location";
          }
          
          setState(() {
            _pickupCtrl.text = address.trim().endsWith(",") 
                ? address.trim().substring(0, address.trim().length - 1) 
                : address.trim();
          });
        } else {
          setState(() {
            _pickupCtrl.text = 'Current Location';
          });
        }
      } catch (_) {
        setState(() {
          _pickupCtrl.text = 'Current Location';
        });
      }
    } catch (e) {
      setState(() {
        _pickupCtrl.text = 'Current Location';
      });
    }
  }

  Future<String?> _showEditAddressDialog(String label, String currentVal) async {
    final controller = TextEditingController(text: currentVal);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: kWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update $label Address",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: kGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE), width: 1.2),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13, color: kDark),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter address...",
                      hintStyle: TextStyle(color: kMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: kMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Save",
                        style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Timer? _driverAnimTimer;
  double? _lastDriverLat;
  double? _lastDriverLng;

  void _onSearchTextChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      String query = "";
      if (_pickupFocus.hasFocus) {
        query = _pickupCtrl.text.trim();
      } else if (_destFocus.hasFocus) {
        query = _destCtrl.text.trim();
      }
      
      if (query.length >= 2) {
        setState(() => _suggestionsLoading = true);
        final suggestions = await MapplsPlaceService.autocomplete(
          query,
          nearLat: _pickupLat,
          nearLng: _pickupLng,
        );
        if (mounted) {
          setState(() {
            _suggestions = suggestions;
            _suggestionsLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _suggestionsLoading = false;
          });
        }
      }
    });
  }

  Future<void> _selectSuggestion(MapplsPlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    
    final isPickup = _pickupFocus.hasFocus;
    
    if (isPickup) {
      _pickupCtrl.text = suggestion.placeName;
      if (suggestion.latitude != null && suggestion.longitude != null) {
        _pickupLat = suggestion.latitude!;
        _pickupLng = suggestion.longitude!;
      } else {
        setState(() => _fareLoading = true);
        final details = await MapplsPlaceService.placeDetail(suggestion.eLoc);
        if (details != null && details.latitude != null) {
          _pickupLat = details.latitude!;
          _pickupLng = details.longitude!;
        }
        setState(() => _fareLoading = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _destFocus.requestFocus();
        }
      });
    } else {
      _destCtrl.text = suggestion.placeName;
      if (suggestion.latitude != null && suggestion.longitude != null) {
        _dropLat = suggestion.latitude!;
        _dropLng = suggestion.longitude!;
      } else {
        setState(() => _fareLoading = true);
        final details = await MapplsPlaceService.placeDetail(suggestion.eLoc);
        if (details != null && details.latitude != null) {
          _dropLat = details.latitude!;
          _dropLng = details.longitude!;
        }
        setState(() => _fareLoading = false);
      }
    }
    
    setState(() {
      _suggestions = [];
    });
    
    if (_destCtrl.text.isNotEmpty && _pickupCtrl.text.isNotEmpty) {
      await _loadFare();
      setState(() => _step = 'confirm');
    }
  }

  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * (pi / 180.0);
    final rLat1 = lat1 * (pi / 180.0);
    final rLat2 = lat2 * (pi / 180.0);

    final y = sin(dLng) * cos(rLat2);
    final x = cos(rLat1) * sin(rLat2) - sin(rLat1) * cos(rLat2) * cos(dLng);

    final angle = atan2(y, x) * (180.0 / pi);
    return (angle + 360.0) % 360.0;
  }

  Future<void> _updateDriverMarkerAnimated(double newLat, double newLng) async {
    if (_mapController == null) return;

    final prevLat = _lastDriverLat ?? _driverLat ?? newLat;
    final prevLng = _lastDriverLng ?? _driverLng ?? newLng;

    _lastDriverLat = newLat;
    _lastDriverLng = newLng;

    final bearing = _calculateBearing(prevLat, prevLng, newLat, newLng);

    final distance = Geolocator.distanceBetween(prevLat, prevLng, newLat, newLng);
    if (distance == 0 || distance > 2000) {
      await _updateDriverSymbol(newLat, newLng, bearing);
      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(newLat, newLng)));
      return;
    }

    int step = 0;
    const int totalSteps = 40;
    _driverAnimTimer?.cancel();
    _driverAnimTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (!mounted || _mapController == null) {
        timer.cancel();
        return;
      }
      step++;
      final double fraction = step / totalSteps;
      final double lat = prevLat + (newLat - prevLat) * fraction;
      final double lng = prevLng + (newLng - prevLng) * fraction;

      await _updateDriverSymbol(lat, lng, bearing);

      if (step % 5 == 0) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
      }

      if (step >= totalSteps) {
        timer.cancel();
      }
    });
  }

  Future<void> _updateDriverSymbol(double lat, double lng, [double? bearing]) async {
    final iconName = _getVehicleIconName();
    final useIcon = _registeredIcons.contains(iconName);
    final emoji = _getVehicleEmoji(_selectedVehicleType);

    try {
      if (_driverSymbol != null) {
        await _mapController!.updateSymbol(_driverSymbol!, SymbolOptions(
          geometry: LatLng(lat, lng),
          iconRotate: bearing,
          iconImage: useIcon ? iconName : null,
          iconSize: useIcon ? 0.9 : null,
          textField: useIcon ? null : emoji,
          textSize: useIcon ? null : 32.0,
        ));
      } else {
        _driverSymbol = await _mapController!.addSymbol(SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: useIcon ? iconName : null,
          iconSize: useIcon ? 0.9 : null,
          textField: useIcon ? null : emoji,
          textSize: useIcon ? null : 32.0,
          textOffset: const Offset(0, 0),
          iconRotate: bearing,
        ));
      }
    } catch (_) {
      try {
        _driverSymbol = await _mapController!.addSymbol(SymbolOptions(
          geometry: LatLng(lat, lng),
          iconImage: useIcon ? iconName : null,
          iconSize: useIcon ? 0.9 : null,
          textField: useIcon ? null : emoji,
          textSize: useIcon ? null : 32.0,
          textOffset: const Offset(0, 0),
          iconRotate: bearing,
        ));
      } catch (_) {}
    }
  }

  Future<void> _drawRiderTripRoute() async {
    if (_mapController == null) return;
    
    LatLng? source;
    LatLng? destination;
    
    final status = _normalizeTripStatus(_tripStatus);
    
    if (status == 'accepted' || status == 'driver_assigned' || status == 'arrived') {
      if (_driverLat != null && _driverLng != null) {
        source = LatLng(_driverLat!, _driverLng!);
        destination = LatLng(_pickupLat, _pickupLng);
      } else {
        source = LatLng(_pickupLat, _pickupLng);
        destination = LatLng(_dropLat, _dropLng);
      }
    } else if (status == 'started') {
      if (_driverLat != null && _driverLng != null) {
        source = LatLng(_driverLat!, _driverLng!);
      } else {
        source = LatLng(_pickupLat, _pickupLng);
      }
      destination = LatLng(_dropLat, _dropLng);
    } else {
      source = LatLng(_pickupLat, _pickupLng);
      destination = LatLng(_dropLat, _dropLng);
    }
    
    if (source != null && destination != null) {
      try {
        final points = await MapService.getRoute(source, destination);
        if (points.isNotEmpty && mounted) {
          _mapController!.clearLines();
          await _mapController!.addLine(LineOptions(
            geometry: points,
            lineColor: status == 'started' ? "#00C853" : "#FF6B00",
            lineWidth: 5.0,
            lineOpacity: 0.8,
          ));
        }
      } catch (e) {
        debugPrint('Error drawing trip route: $e');
      }
    }
  }

  String _getVehicleIconName() {
    final type = _selectedVehicleType.toLowerCase();
    if (type.contains('bike')) {
      return 'custom-bike';
    } else if (type.contains('auto')) {
      return 'custom-auto';
    } else if (type.contains('toto')) {
      return 'custom-toto';
    } else if (type.contains('ambulance')) {
      return 'custom-ambulance';
    } else {
      return 'custom-car';
    }
  }

  Future<void> _registerCustomIcons(MapplsMapController controller) async {
    final assets = {
      'custom-bike': 'assets/images/bike.png',
      'custom-car': 'assets/images/car.png',
      'custom-auto': 'assets/images/auto.png',
      'custom-toto': 'assets/images/toto.png',
      'custom-ambulance': 'assets/images/ambulance.png',
    };
    for (final entry in assets.entries) {
      if (_registeredIcons.contains(entry.key)) continue;
      try {
        final ByteData data = await rootBundle.load(entry.value);
        final ui.Codec codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 120,
        );
        final ui.FrameInfo fi = await codec.getNextFrame();
        final ByteData? pngBytes = await fi.image.toByteData(format: ui.ImageByteFormat.png);
        if (pngBytes != null) {
          await controller.addImage(entry.key, pngBytes.buffer.asUint8List());
          _registeredIcons.add(entry.key);
          debugPrint("Successfully registered custom map icon: ${entry.key}");
        }
      } catch (e) {
        debugPrint("Failed to register custom map icon ${entry.key}: $e");
      }
    }
  }

  Future<void> _loadNearbyDriversOnMap() async {
    if (_mapController == null) return;
    
    // Clear old driver symbols
    for (final sym in _driverSymbols) {
      try {
        await _mapController!.removeSymbol(sym);
      } catch (_) {}
    }
    _driverSymbols.clear();

    List<LatLng> coordsToShow = [];
    try {
      final res = await ApiService.getNearbyDrivers(
        lat: _pickupLat,
        lng: _pickupLng,
        radius: 5.0,
        vehicleType: _selectedVehicleType,
      );

      if (res['success'] == true && res['data'] != null) {
        final List? drivers = res['data']['drivers'] as List?;
        if (drivers != null) {
          for (final d in drivers) {
            final double? lat = (d['lat'] as num?)?.toDouble();
            final double? lng = (d['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              coordsToShow.add(LatLng(lat, lng));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading nearby drivers from server: $e. Using mock fallback.');
    }

    try {
      // Generate random offsets around pickup to ensure we show 3 to 5 drivers nearby
      final targetCount = 3 + Random().nextInt(3); // 3, 4, or 5 drivers
      if (coordsToShow.length > targetCount) {
        coordsToShow = coordsToShow.sublist(0, targetCount);
      } else {
        final random = Random();
        while (coordsToShow.length < targetCount) {
          final double latOffset = (random.nextDouble() - 0.5) * 0.006; 
          final double lngOffset = (random.nextDouble() - 0.5) * 0.006;
          coordsToShow.add(LatLng(_pickupLat + latOffset, _pickupLng + lngOffset));
        }
      }      final iconName = _getVehicleIconName();
      final useIcon = _registeredIcons.contains(iconName);
      final emoji = _getVehicleEmoji(_selectedVehicleType);

      // Add drivers to the map using correct icon or emoji fallback
      for (final coord in coordsToShow) {
        final sym = await _mapController!.addSymbol(SymbolOptions(
          geometry: coord,
          iconImage: useIcon ? iconName : null,
          iconSize: useIcon ? 0.9 : null,
          textField: useIcon ? null : emoji,
          textSize: useIcon ? null : 32.0,
        ));
        _driverSymbols.add(sym);
      }
      debugPrint('Added ${_driverSymbols.length} nearby drivers to map');
    } catch (e) {
      debugPrint('Error adding nearby driver symbols to map: $e');
    }
  }

  List<DropdownMenuItem<String>> _buildDropdownItems(ServiceItem service) {
    if (service.bikeOnly) {
      return [
        DropdownMenuItem(
          value: 'bike',
          child: Row(
            children: [
              ServiceIconWidget(icon: 'bike', size: 20),
              const SizedBox(width: 8),
              const Text('Bike', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ];
    }
    if (service.id == 6) {
      return [
        DropdownMenuItem(
          value: 'ambulance',
          child: Row(
            children: [
              ServiceIconWidget(icon: 'ambulance', size: 20),
              const SizedBox(width: 8),
              const Text('Ambulance', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ];
    }
    return [
      DropdownMenuItem(
        value: 'ac_cab',
        child: Row(
          children: [
            ServiceIconWidget(icon: 'ac_cab', size: 20),
            const SizedBox(width: 8),
            const Text('AC Cab', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'non_ac_cab',
        child: Row(
          children: [
            ServiceIconWidget(icon: 'non_ac_cab', size: 20),
            const SizedBox(width: 8),
            const Text('Non-AC Cab', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'bike',
        child: Row(
          children: [
            ServiceIconWidget(icon: 'bike', size: 20),
            const SizedBox(width: 8),
            const Text('Bike', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'auto',
        child: Row(
          children: [
            ServiceIconWidget(icon: 'auto', size: 20),
            const SizedBox(width: 8),
            const Text('Auto', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'toto',
        child: Row(
          children: [
            ServiceIconWidget(icon: 'toto', size: 20),
            const SizedBox(width: 8),
            const Text('Toto', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ];
  }

  Future<void> _loadEstimatedFare() async {
    await _loadFare();
  }

  Future<void> _loadFare() async {
    setState(() => _fareLoading = true);
    try {
      if (_destCtrl.text.isNotEmpty) {
        try {
          List<geo.Location> locations =
              await geo.locationFromAddress(_destCtrl.text);
          if (locations.isNotEmpty) {
            _dropLat = locations.first.latitude;
            _dropLng = locations.first.longitude;
          }
        } catch (e) {
          debugPrint('Geocoding drop error: $e');
        }
      }
      if (_pickupCtrl.text.isNotEmpty &&
          _pickupCtrl.text != 'Current Location') {
        try {
          List<geo.Location> locations =
              await geo.locationFromAddress(_pickupCtrl.text);
          if (locations.isNotEmpty) {
            _pickupLat = locations.first.latitude;
            _pickupLng = locations.first.longitude;
          }
        } catch (e) {
          debugPrint('Geocoding pickup error: $e');
        }
      }

      final res = await ApiService.estimateFare(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        dropLat: _dropLat,
        dropLng: _dropLng,
        vehicleType: _selectedVehicleType,
      );
      if (res['success'] == true) {
        setState(() {
          _estimatedFare = (res['data']?['estimated_fare'] ?? 0.0).toDouble();
          _estimatedDistance = (res['data']?['distance_km'] ?? 0.0).toDouble();
          _estimatedDuration = (res['data']?['duration_min'] ?? 0).toInt();
        });
        _revalidateAppliedPromo();
      }
    } catch (e) {
      setState(() {
        _estimatedFare = 0.0;
        _estimatedDistance = 0.0;
        _estimatedDuration = 0;
      });
    }
    setState(() => _fareLoading = false);
  }

  Future<void> _updateDriverMarker(double lat, double lng) async {
    if (_mapController == null) return;
    try {
      if (_driverSymbol != null) {
        await _mapController!.removeSymbol(_driverSymbol!);
      }
      _driverSymbol = await _mapController!.addSymbol(SymbolOptions(
        geometry: LatLng(lat, lng),
        iconImage: 'car-15',
        iconSize: 2.0,
        iconColor: '#FF6B00',
        textField: 'Driver',
        textOffset: const Offset(0, -1.5),
        textColor: '#FF6B00',
        textSize: 12.0,
      ));
    } catch (e) {
      debugPrint('Driver marker update error: $e');
    }
  }

  Future<void> _loadActiveTripDetails() async {
    setState(() => _fareLoading = true);
    try {
      final res = await ApiService.getActiveTrip();
      if (res['success'] == true && res['data']?['active_trip'] != null) {
        final trip = res['data']['active_trip'];
        setState(() {
          _tripId = (trip['id'] as num?)?.toInt() ?? _tripId;
          _tripStatus = _normalizeTripStatus(trip['status']);
          _pickupCtrl.text = trip['pickup_address'] ?? '';
          _pickupLat = (trip['pickup_lat'] as num?)?.toDouble() ?? 22.5726;
          _pickupLng = (trip['pickup_lng'] as num?)?.toDouble() ?? 88.3639;
          _dropLat = (trip['drop_lat'] as num?)?.toDouble() ?? 22.5850;
          _dropLng = (trip['drop_lng'] as num?)?.toDouble() ?? 88.3950;
          _estimatedFare = (trip['estimated_fare'] as num?)?.toDouble() ?? 0.0;
          _selectedVehicleType = trip['vehicle_type'] ?? _selectedVehicleType;
          _otpCode = _readTripOtp(trip);

          if (trip['driver'] != null) {
            _assignedDriver = trip['driver'];
            _driverLat = (trip['driver']['current_lat'] as num?)?.toDouble();
            _driverLng = (trip['driver']['current_lng'] as num?)?.toDouble();
          }

          final riderId = AuthService.riderId;
          final token = AuthService.token;
          if (riderId != null && token != null) {
            _connectSocket(riderId, token);
          }
        });
      }
    } catch (e) {
      debugPrint('Load active trip details error: $e');
    }
    setState(() => _fareLoading = false);
  }

  void _connectSocket(int riderId, String token) {
    setState(() => _socketDisconnected = false);

    RiderSocketService.onDisconnect = () {
      if (mounted) {
        setState(() {
          _socketDisconnected = true;
        });
      }
    };

    RiderSocketService.onReconnect = () async {
      if (mounted) {
        setState(() {
          _socketDisconnected = false;
        });
      }
      try {
        final res = await ApiService.reconnectTrip();
        if (res['success'] == true && res['data'] != null) {
          final data = res['data'];
          final isSearching = data['searching'] == true;
          final activeTrip = data['active_trip'] as Map<String, dynamic>?;

          if (isSearching) {
            setState(() {
              _searching = true;
              _booked = true;
            });
            _startSearchPolling();
          } else if (activeTrip != null) {
            final tripId = (activeTrip['id'] as num?)?.toInt();
            final status = _normalizeTripStatus(activeTrip['status']);
            final otpCode = _readTripOtp(activeTrip);

            Map<String, dynamic>? driver;
            double? dLat;
            double? dLng;
            if (activeTrip['driver'] != null) {
              driver = activeTrip['driver'];
              dLat = (activeTrip['driver']['current_lat'] as num?)?.toDouble();
              dLng = (activeTrip['driver']['current_lng'] as num?)?.toDouble();
            }

            setState(() {
              _tripId = tripId;
              _booked = true;
              _searching = false;
              _step = 'tracking';
              _tripStatus = status;
              _otpCode = otpCode;
              _assignedDriver = driver;
              _driverLat = dLat;
              _driverLng = dLng;
            });
            _stopSearchPolling();
            _startTrackingPolling();

            if (dLat != null && dLng != null) {
              _updateDriverMarkerAnimated(dLat, dLng);
              _drawRiderTripRoute();
            }
          } else {
            setState(() {
              _booked = false;
              _searching = false;
              _step = 'input';
              _tripId = null;
            });
          }
        }
      } catch (e) {
        debugPrint('Error during trip reconnect restoration: $e');
      }
    };

    RiderSocketService.connect(riderId, token);
    RiderSocketService.onMessage = (data) {
      debugPrint('Rider socket message: $data');
      final type = data["type"];
      if (type == "kicked") {
        RiderSocketService.disconnect();
        AuthService.logout(forced: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Logged in on another device"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (type == "driver_assigned" ||
          type == "driver_accepted" ||
          type == "trip_accepted" ||
          type == "accepted") {
        final activeTrip = data["active_trip"] as Map<String, dynamic>?;
        setState(() {
          _booked = true;
          _searching = false;
          _step = 'tracking';
          _tripId = (data["trip_id"] as num?)?.toInt() ??
              (activeTrip?["id"] as num?)?.toInt() ??
              _tripId;
          _tripStatus = _normalizeTripStatus(
              activeTrip?["status"] ?? data["status"] ?? 'driver_assigned');
          _assignedDriver = activeTrip?["driver"] ??
              data["driver"] ??
              {
                "name": data["driver_name"],
                "phone": data["driver_phone"],
                "profile_pic_url": data["profile_pic"],
                "vehicle_model": data["vehicle_model"],
                "rc_number": data["rc_number"],
              };
          _otpCode = _readTripOtp(data) ?? _readTripOtp(activeTrip);
          _driverLat = (_assignedDriver?["current_lat"] as num?)?.toDouble();
          _driverLng = (_assignedDriver?["current_lng"] as num?)?.toDouble();
        });
        _stopSearchPolling();
        _startTrackingPolling();
      } else if (type == "no_driver_found") {
        _stopSearchPolling();
        setState(() {
          _booked = false;
          _searching = false;
          _step = 'input';
          _tripId = null;
          _otpCode = null;
          _assignedDriver = null;
          _driverLat = null;
          _driverLng = null;
          _bonusAmount = 0;
        });
        _showNoDriverDialog();
      } else if (type == "driver_location") {
        final lat = (data["lat"] as num?)?.toDouble();
        final lng = (data["lng"] as num?)?.toDouble();
        if (lat != null && lng != null) {
          setState(() {
            _driverLat = lat;
            _driverLng = lng;
          });
          _updateDriverMarkerAnimated(lat, lng);
          _drawRiderTripRoute();
        }
      } else if (type == "driver_arrived") {
        setState(() {
          _tripStatus = 'arrived';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Driver has arrived at pickup location! 📍"),
            backgroundColor: kOrange));
      } else if (type == "trip_started") {
        setState(() {
          _tripStatus = 'started';
          _otpCode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Trip started! Have a safe journey. 🚗"),
            backgroundColor: Colors.green));
        _openNavigation(_dropLat, _dropLng);
      } else if (type == "trip_completed") {
        setState(() {
          _tripStatus = 'completed';
          _otpCode = null;
        });
        _stopSearchPolling();
        _stopTrackingPolling();
        RiderSocketService.disconnect();
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TripReceiptScreen(
                    tripId: _tripId!,
                    onClose: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
                        (route) => false,
                      );
                    },
                  ),
            ));
      } else if (type == "trip_cancelled") {
        RiderSocketService.disconnect();
        _stopSearchPolling();
        _stopTrackingPolling();
        setState(() {
          _booked = false;
          _searching = false;
          _step = 'input';
          _tripId = null;
          _otpCode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Trip cancelled by driver: ${data["reason"] ?? 'No reason given'}"),
            backgroundColor: Colors.red));
      } else if (type == "chat_message") {
        if (_tripId != null && !_isChatScreenOpen) {
          _openChatScreen();
        }
      }
    };
  }

  @override
  void dispose() {
    _stopSearchPolling();
    RiderSocketService.onMessage = null;
    RiderSocketService.onDisconnect = null;
    RiderSocketService.onReconnect = null;
    WidgetsBinding.instance.removeObserver(this);
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _debounceTimer?.cancel();
    _driverAnimTimer?.cancel();
    super.dispose();
  }

  void _showNoDriverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😔', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text(
                'We are sorry',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: kDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'No driver available near you',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelCurrentRide({bool closeAfterCancel = false}) async {
    final tripId = _tripId;
    try {
      if (tripId != null) {
        final res = await ApiService.cancelTrip(tripId, 'Cancelled by rider');
        if (res['success'] != true) {
          throw Exception(res['error'] ?? 'Cancel failed');
        }
      }
      if (!mounted) return;
      RiderSocketService.disconnect();
      _stopSearchPolling();
      setState(() {
        _booked = false;
        _searching = false;
        _step = 'input';
        _tripId = null;
        _otpCode = null;
        _assignedDriver = null;
        _driverLat = null;
        _driverLng = null;
        _bonusAmount = 0;
        _appliedPromoCode = null;
        _promoDiscount = 0.0;
        _isManualPromoApplied = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride request cancelled')),
      );
      if (closeAfterCancel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onBack();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel ride')),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_step == 'tracking') {
      body = _buildTrackingStep();
    } else if (_booked) {
      if (_searching) {
        body = _buildSearchingState();
      } else {
        body = BookingSuccessScreen(
          service: widget.service,
          destination: _destCtrl.text,
          payment: _paymentMethod,
          onDone: () {
            setState(() {
              _step = 'tracking';
            });
            _startTrackingPolling();
          },
        );
      }
    } else if (_step == 'confirm') {
      body = _buildConfirmStep();
    } else {
      body = _buildInputStep();
    }

    return WillPopScope(
      onWillPop: () async {
        final status = _normalizeTripStatus(_tripStatus);
        if (_step == 'tracking' &&
            (status == 'accepted' || status == 'arrived' || status == 'started')) {
          return false;
        }
        if (_searching) {
          await _cancelCurrentRide(closeAfterCancel: true);
          return false;
        }
        widget.onBack();
        return false;
      },
      child: body,
    );
  }

  Widget _buildSearchingState() {
    final isAmbulance = widget.service.vehicleType == 'ambulance';
    final timeStr = "$_searchSecondsLeft sec";

    return Stack(
      children: [
          Positioned.fill(
            child: MapplsMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_pickupLat, _pickupLng),
                zoom: 14.2,
              ),
              onMapCreated: (MapplsMapController controller) {
                _mapController = controller;
              },
              onStyleLoadedCallback: () async {
                if (_mapController == null) return;
              try {
                await _registerCustomIcons(_mapController!);
                // Add Pickup marker
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_pickupLat, _pickupLng),
                  iconImage: 'marker-15',
                  iconSize: 2.0,
                  iconColor: '#FF6B00',
                  textField: 'Pickup',
                  textOffset: const Offset(0, 1.5),
                  textColor: '#FF6B00',
                  textSize: 12.0,
                ));
                
                final iconName = _getVehicleIconName();
                final useIcon = _registeredIcons.contains(iconName);
                final emoji = _getVehicleEmoji(_selectedVehicleType);

                 // Add 3 mock nearby driver icons to represent active search using correct icon or emoji fallback
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_pickupLat + 0.0035, _pickupLng - 0.0025),
                  iconImage: useIcon ? iconName : null,
                  iconSize: useIcon ? 0.9 : null,
                  textField: useIcon ? null : emoji,
                  textSize: useIcon ? null : 32.0,
                ));
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_pickupLat - 0.0018, _pickupLng + 0.0042),
                  iconImage: useIcon ? iconName : null,
                  iconSize: useIcon ? 0.9 : null,
                  textField: useIcon ? null : emoji,
                  textSize: useIcon ? null : 32.0,
                ));
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_pickupLat + 0.0022, _pickupLng + 0.0031),
                  iconImage: useIcon ? iconName : null,
                  iconSize: useIcon ? 0.9 : null,
                  textField: useIcon ? null : emoji,
                  textSize: useIcon ? null : 32.0,
                ));
              } catch (_) {}
            },
            myLocationEnabled: true,
          ),
          ),



          // Bottom Sheet Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle pull bar
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header with Timer Row
                  Row(
                    children: [
                      // Circular Progress / Pulse container
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              value: _searchSecondsLeft / _initialSearchDuration.toDouble(),
                              strokeWidth: 4.5,
                              color: kOrange,
                              backgroundColor: const Color(0xFFF2F4F7),
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF3E0),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                widget.service.icon,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Text & Timer Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAmbulance
                                  ? 'Finding your ambulance...'
                                  : 'Finding your driver...',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 14,
                                  color: kOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$timeStr remaining',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kOrange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF2F4F7), height: 1),
                  const SizedBox(height: 16),

                  if (!isAmbulance) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No one accepting? Add a bonus!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: kDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [10, 20, 30, 40, 50, 100].map((amount) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () async {
                                if (_tripId == null) return;
                                final oldBonusAmount = _bonusAmount;
                                final oldSearchSecondsLeft = _searchSecondsLeft;
                                final startTime = DateTime.now();
                                setState(() {
                                  _bonusAmount += amount;
                                });
                                _startSearchingTimer(seconds: 90);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('+₹$amount bonus added!'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                try {
                                  final res = await ApiService.addBonus(
                                    _tripId!,
                                    amount.toDouble(),
                                  );
                                  if (res['success'] != true) {
                                    throw Exception(res['error'] ?? 'Server error');
                                  }
                                } catch (e) {
                                  if (mounted && _searching && _tripId != null) {
                                    final elapsed = DateTime.now().difference(startTime).inSeconds;
                                    setState(() {
                                      _bonusAmount = oldBonusAmount;
                                      final revertedSeconds = oldSearchSecondsLeft - elapsed;
                                      _searchSecondsLeft = revertedSeconds > 0 ? revertedSeconds : 0;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add bonus: ${e.toString().replaceAll('Exception: ', '').replaceAll('Exception:', '').trim()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF6F3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: kOrange.withOpacity(0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  '+₹$amount',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: kOrange,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (_bonusAmount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Total Fare: ₹${_estimatedFare.toStringAsFixed(0)} + ₹${_bonusAmount.toStringAsFixed(0)} = ₹${(_estimatedFare + _bonusAmount).toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kOrange,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _cancelCurrentRide,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFFFF5F5),
                      ),
                      child: const Text(
                        'Cancel Search',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_socketDisconnected) _buildReconnectionOverlay(),
        ],
      );
  }

  Widget _buildReconnectionOverlay() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.orange.shade100, width: 1.5),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(kOrange),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Connection Lost',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Attempting to reconnect every 5s...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
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

  Widget _buildInputStep() {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double topPadding = MediaQuery.of(context).padding.top + 8;

    return Container(
      color: kWhite,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.genericMode) ...[
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: kOrangeLight,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Center(
                              child: ServiceIconWidget(
                                  icon: 'ac_cab', size: 18))),
                      const SizedBox(width: 8),
                      const Text('Book Ride',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kDark)),
                    ] else ...[
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: widget.service.color,
                              borderRadius: BorderRadius.circular(8)),
                          child: Center(
                              child: ServiceIconWidget(
                                  icon: widget.service.icon, size: 18))),
                      const SizedBox(width: 8),
                      Text(widget.service.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: kDark)),
                    ],
                    if (widget.service.bikeOnly) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: kOrangeLight,
                            borderRadius: BorderRadius.circular(99),
                            border:
                                Border.all(color: kOrange.withValues(alpha: 0.2))),
                        child: const Text('🏍️ Bike only',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: kOrange)),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isKeyboardOpen ? 10 : 16),
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: kOrangeLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: kOrange)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: _pickupCtrl,
                              focusNode: _pickupFocus,
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Pickup location'),
                              style:
                                  const TextStyle(fontSize: 13, color: kDark))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                StatefulBuilder(
                  builder: (_, ss) => Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: kGray,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: kDark,
                                borderRadius: BorderRadius.circular(1.5))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _destCtrl,
                            focusNode: _destFocus,
                            autofocus: true,
                            onChanged: (_) => ss(() {}),
                            decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: widget.service.category == 'delivery'
                                    ? 'Delivery address...'
                                    : 'Where to?'),
                            style: const TextStyle(fontSize: 13, color: kDark),
                          ),
                        ),
                        if (_destCtrl.text.isNotEmpty)
                          GestureDetector(
                              onTap: () {
                                _destCtrl.clear();
                                ss(() {});
                              },
                              child: const Text('✕',
                                  style:
                                      TextStyle(color: kMuted, fontSize: 14))),
                      ],
                    ),
                  ),
                ),
                if (widget.service.category == 'ride') ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      ServiceIconWidget(icon: _selectedVehicleType, size: 22),
                      const SizedBox(width: 8),
                      const Text('Vehicle:',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                        value: _selectedVehicleType,
                        items: [
                          DropdownMenuItem(
                            value: 'ac_cab',
                            child: Row(
                              children: [
                                ServiceIconWidget(icon: 'ac_cab', size: 20),
                                const SizedBox(width: 8),
                                const Text('AC Cab', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'non_ac_cab',
                            child: Row(
                              children: [
                                ServiceIconWidget(icon: 'non_ac_cab', size: 20),
                                const SizedBox(width: 8),
                                const Text('Non-AC Cab', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'bike',
                            child: Row(
                              children: [
                                ServiceIconWidget(icon: 'bike', size: 20),
                                const SizedBox(width: 8),
                                const Text('Bike', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'auto',
                            child: Row(
                              children: [
                                ServiceIconWidget(icon: 'auto', size: 20),
                                const SizedBox(width: 8),
                                const Text('Auto', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'toto',
                            child: Row(
                              children: [
                                ServiceIconWidget(icon: 'toto', size: 20),
                                const SizedBox(width: 8),
                                const Text('Toto', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedVehicleType = val);
                            _loadFare();
                            _loadNearbyDriversOnMap();
                          }
                        },
                      ))),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_destCtrl.text.isEmpty) {
                            _destCtrl.text = "Map Selected Location";
                          }
                          setState(() {
                            _dropLat = 22.5850;
                            _dropLng = 88.3950;
                            _step = 'confirm';
                          });
                          _loadFare();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Confirm your location on the map')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: kWhite,
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_rounded, size: 15, color: kDark),
                              SizedBox(width: 6),
                              Text('Select from map',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Stops feature is coming soon!')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: kWhite,
                            border: Border.all(color: const Color(0xFFE4E7EC)),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 15, color: kDark),
                              SizedBox(width: 6),
                              Text('Add stops',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: kDark)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _suggestionsLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(color: kOrange),
                        ),
                      )
                    : _suggestions.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              String? distanceStr;
                              if (suggestion.latitude != null && suggestion.longitude != null) {
                                try {
                                  final distMeters = Geolocator.distanceBetween(
                                    _pickupLat,
                                    _pickupLng,
                                    suggestion.latitude!,
                                    suggestion.longitude!,
                                  );
                                  final distKm = distMeters / 1000.0;
                                  distanceStr = "${distKm.toStringAsFixed(1)} km";
                                } catch (_) {}
                              } else {
                                distanceStr = "${(8.0 + index * 1.2).toStringAsFixed(1)} km";
                              }

                              return GestureDetector(
                                onTap: () => _selectSuggestion(suggestion),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFFF2F4F7), width: 1)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 38,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              color: Color(0xFF667085),
                                              size: 16,
                                            ),
                                            if (distanceStr != null) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                distanceStr,
                                                style: const TextStyle(
                                                  fontSize: 8.0,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF667085),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              suggestion.placeName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: kDark,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (suggestion.placeAddress.isNotEmpty) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                suggestion.placeAddress,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: kMuted,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.favorite_border_rounded,
                                        color: Color(0xFF98A2B3),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SAVED PLACES',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: kMuted,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              ..._quickDests.map((d) {
                                final full = '${d.label}, ${d.sub}';
                                return StatefulBuilder(
                                  builder: (_, ss) => GestureDetector(
                                    onTap: () async {
                                      setState(() => _destCtrl.text = full);
                                      FocusScope.of(context).unfocus();
                                      await _loadFare();
                                      setState(() => _step = 'confirm');
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: _destCtrl.text.startsWith(d.label)
                                              ? kOrangeLight
                                              : kGray,
                                          borderRadius: BorderRadius.circular(10)),
                                      child: Row(
                                        children: [
                                          Container(
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                  color: kWhite,
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black.withOpacity(0.05),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 1.5))
                                                  ]),
                                              child: Center(
                                                  child: Text(d.icon,
                                                      style: const TextStyle(fontSize: 15)))),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(d.label,
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: kDark)),
                                                Text(d.sub,
                                                    style: const TextStyle(
                                                        fontSize: 11, color: kMuted)),
                                              ])),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () async {
                                              final newAddress = await _showEditAddressDialog(d.label, d.sub);
                                              if (newAddress != null && newAddress.trim().isNotEmpty) {
                                                if (d.label == 'Home') {
                                                  await AuthService.setHomeAddress(newAddress.trim());
                                                } else {
                                                  await AuthService.setOfficeAddress(newAddress.trim());
                                                }
                                                setState(() {});
                                                ss(() {});
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: kWhite,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
                                              ),
                                              child: const Icon(
                                                Icons.edit_rounded,
                                                color: Color(0xFF667085),
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                          if (_destCtrl.text.startsWith(d.label)) ...[
                                            const SizedBox(width: 6),
                                            const Text('✓',
                                                style:
                                                    TextStyle(color: kOrange, fontSize: 14)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                const SizedBox(height: 20),
                StatefulBuilder(
                  builder: (_, ss) {
                    final hasText = _destCtrl.text.isNotEmpty;
                    return ElevatedButton(
                      onPressed: hasText
                          ? () async {
                              await _loadFare();
                              setState(() => _step = 'confirm');
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasText
                            ? widget.service.accent
                            : const Color(0xFFEEEEEE),
                        foregroundColor: hasText ? kWhite : kMuted,
                        disabledBackgroundColor: const Color(0xFFEEEEEE),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: hasText ? 8 : 0,
                        shadowColor: widget.service.accent.withOpacity(0.27),
                      ),
                      child: SizedBox(
                          width: double.infinity,
                          child: Center(
                              child: Text(
                                  hasText
                                      ? 'Find ${widget.service.name} →'
                                      : 'Enter a destination',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700)))),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmStep() {
    return Stack(
      children: [
        Positioned.fill(
          child: MapplsMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_pickupLat, _pickupLng),
              zoom: 13,
            ),
            onMapCreated: (MapplsMapController controller) {
              _mapController = controller;
            },
            onStyleLoadedCallback: () async {
              if (_mapController == null) return;
              await _registerCustomIcons(_mapController!);
              
              try {
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_pickupLat, _pickupLng),
                  iconImage: 'marker-15',
                  iconSize: 2.0,
                  iconColor: '#FF6B00',
                  textField: 'Pickup',
                  textOffset: const Offset(0, 1.5),
                  textColor: '#FF6B00',
                ));
              } catch (_) {}

              try {
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_dropLat, _dropLng),
                  iconImage: 'marker-15',
                  iconSize: 2.0,
                  iconColor: '#1A1A1A',
                  textField: 'Drop',
                  textOffset: const Offset(0, 1.5),
                  textColor: '#1A1A1A',
                ));
              } catch (_) {}

              await _loadNearbyDriversOnMap();
              await _drawRiderTripRoute();
            },
            myLocationEnabled: true,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 12,
            ),
            decoration: const BoxDecoration(
                color: kWhite,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 32,
                      offset: Offset(0, -8))
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFDDDDDD),
                            borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 6),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.2),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: widget.service.color,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                      color: kWhite,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2))
                                      ]),
                                  child: Center(
                                      child: ServiceIconWidget(
                                          icon: _selectedVehicleType, size: 18))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Text(_getVehicleLabel(_selectedVehicleType),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: kDark)),
                                    const SizedBox(height: 1),
                                    Text(_getVehicleTag(_selectedVehicleType),
                                        style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: widget.service.accent)),
                                  ])),
                              const SizedBox(width: 8),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedVehicleType,
                                  dropdownColor: kWhite,
                                  borderRadius: BorderRadius.circular(12),
                                  items: _buildDropdownItems(widget.service),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedVehicleType = val;
                                        _fareLoading = true;
                                      });
                                      _loadEstimatedFare();
                                      _loadNearbyDriversOnMap();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                              color: kGray,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFEEEEEE), width: 1.5)),
                          child: Column(
                            children: [
                              Row(children: [
                                Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle, color: kOrange)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_pickupCtrl.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: kDark)))
                              ]),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 17),
                                    width: 1.2,
                                    height: 12,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              Row(children: [
                                Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(1.5),
                                        color: Colors.red.shade400)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(_destCtrl.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11, color: kDark)))
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => setState(() => _useKCoins = !_useKCoins),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _useKCoins
                                  ? const Color(0xFFFFF3E0)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _useKCoins
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFFEEEEEE),
                                  width: 1.5),
                            ),
                            child: Row(children: [
                              const Text('🪙', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              const Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Text('Use K Coins',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                    Text('100 coins = ₹10 discount',
                                        style: TextStyle(
                                            fontSize: 9, color: Colors.grey)),
                                  ])),
                              Container(
                                width: 32,
                                height: 18,
                                decoration: BoxDecoration(
                                    color: _useKCoins
                                        ? const Color(0xFFFF6B35)
                                        : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10)),
                                child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: _useKCoins
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                        margin: const EdgeInsets.all(2),
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showPromoCodeModal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: kGray,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFEEEEEE), width: 1.5)),
                            child: Row(
                              children: [
                                const Text('🎟️',
                                    style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        _appliedPromoCode != null
                                            ? 'Promo Applied: $_appliedPromoCode'
                                            : 'Apply Coupon',
                                        style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: kDark)),
                                    Text(
                                        _appliedPromoCode != null && _promoDiscount > 0
                                            ? 'Saved ₹${_promoDiscount.toStringAsFixed(2)} on this ride'
                                            : 'Get discounts on your fare',
                                        style: TextStyle(
                                            fontSize: 8.5,
                                            color: _appliedPromoCode != null
                                                ? const Color(0xFF4CAF50)
                                                : kMuted,
                                            fontWeight: _appliedPromoCode != null
                                                ? FontWeight.w600
                                                : FontWeight.normal)),
                                  ],
                                )),
                                Text(_appliedPromoCode != null ? 'Remove' : 'Apply',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: _appliedPromoCode != null
                                            ? Colors.red[700]
                                            : kOrange,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => setState(() => _showPaymentModal = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: kGray,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFEEEEEE), width: 1.5)),
                            child: Row(
                              children: [
                                Text(_paymentMethod.icon,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(_paymentMethod.label,
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: kDark)),
                                      Text(_paymentMethod.sub,
                                          style: const TextStyle(
                                              fontSize: 8.5, color: kMuted)),
                                    ])),
                                const Text('Change →',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        color: kOrange,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        if (widget.service.tag == 'Emergency') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Row(children: [
                              Text('🚨', style: TextStyle(fontSize: 10)),
                              SizedBox(width: 4),
                              Expanded(
                                  child: Text(
                                      'Nearest ambulance will be dispatched immediately',
                                      style: TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFFE53935),
                                          fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final body = {
                        "pickup_address": _pickupCtrl.text,
                        "drop_address": _destCtrl.text,
                        "pickup_lat": _pickupLat,
                        "pickup_lng": _pickupLng,
                        "drop_lat": _dropLat,
                        "drop_lng": _dropLng,
                        "vehicle_type": _selectedVehicleType,
                        "service_type":
                            widget.service.category == 'delivery'
                                ? widget.service.name.toLowerCase()
                                : 'ride',
                        "payment_method": _paymentMethod.id,
                        "use_kcoins": _useKCoins,
                        "is_ev_request": widget.service.isEV,
                        "promo_code": _appliedPromoCode,
                      };
                      try {
                        final result = await ApiService.bookTrip(body);
                        if (result["success"] == true) {
                          final bookedTrip =
                              result["data"] as Map<String, dynamic>? ??
                                  const {};
                          final tripId =
                              (bookedTrip["trip_id"] as num?)?.toInt() ??
                                  (result["trip_id"] as num?)?.toInt();
                          setState(() {
                            _booked = true;
                            _searching = true;
                            _tripId = tripId;
                          });
                          _startSearchPolling();
                          final riderId = AuthService.riderId;
                          final token = AuthService.token;
                          if (riderId != null && token != null) {
                            _connectSocket(riderId, token);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(result["error"] ??
                                      "Booking failed")));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Booking error: $e")));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: widget.service.accent,
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                        shadowColor:
                            widget.service.accent.withOpacity(0.27)),
                    child: Text(
                        _fareLoading
                            ? 'Getting fare...'
                            : 'Confirm ${_getVehicleLabel(_selectedVehicleType)} · ₹${(_estimatedFare - _promoDiscount).toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showPaymentModal)
          Positioned.fill(
            child: PaymentModal(
              selected: _paymentMethod,
              onSelect: (pm) => setState(() => _paymentMethod = pm),
              onClose: () => setState(() => _showPaymentModal = false),
            ),
          ),
      ],
    );
  }

  Widget _buildTrackingStep() {
    final tripStatus = _normalizeTripStatus(_tripStatus);
    final showOtp = _shouldShowTripOtp;
    final expectOtp = _shouldExpectTripOtp;
    final driverName = _assignedDriver?['name'] ?? 'Driver';
    final driverPhone = _assignedDriver?['phone'] ?? '';
    final driverPhotoUrl =
        _assignedDriver?['profile_pic_url']?.toString() ??
        _assignedDriver?['profile_pic']?.toString() ?? '';
    final driverRating =
        _assignedDriver?['avg_rating'] ?? _assignedDriver?['rating'] ?? '4.8';
    final vehicleModel = _assignedDriver?['vehicle_model'] ??
        _assignedDriver?['vehicle'] ??
        'Standard Vehicle';
    final vehicleNo = _assignedDriver?['vehicle_no'] ??
        _assignedDriver?['rc_number'] ??
        'T&C Applied';

    Color statusColor = kOrange;
    String statusTitle = 'Driver Assigned';
    String statusSubtitle = 'Driver is on their way to pick you up';

    if (tripStatus == 'requested') {
      statusTitle = 'Searching for Driver';
      statusSubtitle = 'We are matching you with the nearest driver';
    } else if (tripStatus == 'driver_assigned' || tripStatus == 'accepted') {
      statusTitle = 'Trip Accepted';
      statusSubtitle = 'Your driver accepted the ride and is on the way';
    }

    if (tripStatus == 'arrived') {
      statusColor = Colors.green;
      statusTitle = 'Driver Arrived';
      statusSubtitle = 'Please meet the driver at your pickup point';
    } else if (tripStatus == 'started') {
      statusColor = Colors.blue;
      statusTitle = 'On Trip';
      statusSubtitle = 'Heading to your destination';
    } else if (tripStatus == 'completed') {
      statusColor = Colors.grey;
      statusTitle = 'Trip Completed';
      statusSubtitle = 'Thank you for riding with KRide';
    }

    // Dynamic distance & ETA calculation
    double distKm = 0.0;
    int etaMinutes = 0;
    String? distanceStr;
    String? durationStr;
    if (_driverLat != null && _driverLng != null) {
      final double targetLat = (tripStatus == 'started') ? _dropLat : _pickupLat;
      final double targetLng = (tripStatus == 'started') ? _dropLng : _pickupLng;
      final double distMeters = Geolocator.distanceBetween(_driverLat!, _driverLng!, targetLat, targetLng);
      distKm = distMeters / 1000.0;
      distanceStr = "${distKm.toStringAsFixed(1)} km";
      etaMinutes = (distKm * 2.0).round() + 1;
      durationStr = "$etaMinutes min";
    }

    return Stack(
      children: [
        Positioned.fill(
          child: MapplsMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_pickupLat, _pickupLng),
              zoom: 14,
            ),
            onMapCreated: (MapplsMapController controller) {
              _mapController = controller;
            },
            onStyleLoadedCallback: () async {
              if (_mapController == null) return;
              await _registerCustomIcons(_mapController!);
              
              try {
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_pickupLat, _pickupLng),
                  iconImage: 'marker-15',
                  iconSize: 2.0,
                  iconColor: '#FF6B00',
                  textField: 'Pickup',
                  textOffset: const Offset(0, 1.5),
                  textColor: '#FF6B00',
                ));
              } catch (_) {}

              try {
                await _mapController!.addSymbol(SymbolOptions(
                  geometry: LatLng(_dropLat, _dropLng),
                  iconImage: 'marker-15',
                  iconSize: 2.0,
                  iconColor: '#1A1A1A',
                  textField: 'Drop',
                  textOffset: const Offset(0, 1.5),
                  textColor: '#1A1A1A',
                ));
              } catch (_) {}

              try {
                if (_driverLat != null && _driverLng != null) {
                  await _updateDriverMarkerAnimated(_driverLat!, _driverLng!);
                }
              } catch (_) {}

              await _drawRiderTripRoute();
            },
            myLocationEnabled: true,
          ),
        ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _buildTrackingToast(tripStatus),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              color: const Color(0xFFF9F9F9), // kBg
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _buildDistanceBanner(distKm, etaMinutes, tripStatus),
                    const SizedBox(height: 8),
                    _buildDriverCard(context, driverName, driverPhone, driverPhotoUrl, driverRating, vehicleModel, vehicleNo),
                    const SizedBox(height: 8),
                    _buildOtpSosRow(context, showOtp, expectOtp, tripStatus),
                    if (tripStatus == 'requested' ||
                        tripStatus == 'driver_assigned' ||
                        tripStatus == 'accepted' ||
                        tripStatus == 'arrived') ...[
                      const SizedBox(height: 8),
                      _buildCancelButton(context),
                    ],
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom > 0
                            ? MediaQuery.of(context).padding.bottom
                            : 12),
                  ],
                ),
              ),
            ),
          ),
          if (_socketDisconnected) _buildReconnectionOverlay(),
        ],
      );
  }

  Widget _buildTrackingToast(String tripStatus) {
    String title = 'Ride accepted!';
    String subtitle = 'Your driver is on the way';
    Color iconBgColor = const Color(0xFF27AE60);
    IconData iconData = Icons.check;

    if (tripStatus == 'requested') {
      title = 'Finding your ride';
      subtitle = 'Matching with nearby drivers';
      iconBgColor = const Color(0xFFFF6B00);
      iconData = Icons.search_rounded;
    } else if (tripStatus == 'arrived') {
      title = 'Driver arrived!';
      subtitle = 'Meet driver at the pickup point';
      iconBgColor = const Color(0xFF27AE60);
      iconData = Icons.check_circle_outline_rounded;
    } else if (tripStatus == 'started') {
      title = 'Trip started!';
      subtitle = 'Heading to destination';
      iconBgColor = const Color(0xFF007AFF);
      iconData = Icons.navigation_rounded;
    } else if (tripStatus == 'completed') {
      title = 'Trip completed!';
      subtitle = 'Thank you for riding with us';
      iconBgColor = Colors.grey;
      iconData = Icons.done_all_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceBanner(double distanceKm, int etaMinutes, String tripStatus) {
    const Color panelOrange = Color(0xFFE84917);
    const Color panelOrangeSoft = Color(0xFFFFF0EB);
    const Color panelOrangeBorder = Color(0xFFFFCBB5);
    const Color panelTextDark = Color(0xFF1A1A1A);

    String textTitle;
    String textSubtitle;
    if (tripStatus == 'started') {
      textTitle = 'On Trip';
      textSubtitle = 'Arriving in $etaMinutes min';
    } else if (tripStatus == 'arrived') {
      textTitle = 'Driver has arrived!';
      textSubtitle = 'Please meet the driver';
    } else {
      textTitle = 'Arriving in $etaMinutes min';
      textSubtitle = 'Your driver is on the way';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: panelOrangeSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: panelOrangeBorder, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_car, color: panelOrange, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: panelOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    textSubtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: panelTextDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Live tracking pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: panelOrange, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.wifi, color: panelOrange, size: 12),
                  SizedBox(width: 3),
                  Text(
                    'Live tracking',
                    style: TextStyle(
                      fontSize: 10,
                      color: panelOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatScreen() {
    if (_tripId == null) return;
    if (_isChatScreenOpen) return;
    setState(() {
      _isChatScreenOpen = true;
    });
    final driverName = _assignedDriver?['name'] ?? 'Driver';
    final driverPhone = _assignedDriver?['phone'] ?? '';
    final driverPhotoUrl = _assignedDriver?['profile_pic_url']?.toString() ??
        _assignedDriver?['profile_pic']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripChatScreen(
          tripId: _tripId!,
          driverName: driverName,
          driverPhone: driverPhone,
          driverPhotoUrl: driverPhotoUrl,
          onClose: () {
            setState(() {
              _isChatScreenOpen = false;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps application')),
          );
        }
      }
    } catch (e) {
      try {
        final webUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (innerError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching navigation: $innerError')),
        );
      }
    }
  }

  Widget _buildDriverCard(
    BuildContext context,
    String driverName,
    String driverPhone,
    String driverPhotoUrl,
    dynamic driverRating,
    String vehicleModel,
    String vehicleNo,
  ) {
    const Color panelOrangeSoft = Color(0xFFFFF0EB);
    const Color panelOrangeBorder = Color(0xFFFFCBB5);
    const Color panelOrange = Color(0xFFE84917);
    const Color panelTextDark = Color(0xFF1A1A1A);
    const Color panelTextGrey = Color(0xFF8A8A8A);
    const Color panelDivider = Color(0xFFF0F0F0);
    const Color panelCardBg = Color(0xFFFFFFFF);

    final initials = driverName.isNotEmpty
        ? driverName.trim().split(' ').map((e) => e[0]).take(1).join()
        : '?';

    double ratingVal = 4.8;
    if (driverRating != null) {
      if (driverRating is num) {
        ratingVal = driverRating.toDouble();
      } else {
        ratingVal = double.tryParse(driverRating.toString()) ?? 4.8;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panelCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Avatar + name + rating
            Row(
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: panelOrangeSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: panelOrangeBorder, width: 1.5),
                    image: driverPhotoUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(driverPhotoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: driverPhotoUrl.isEmpty
                      ? Text(
                          initials.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: panelOrange,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Name + phone + vehicle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: panelTextDark,
                        ),
                      ),
                      if (driverPhone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          driverPhone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: panelTextGrey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        '$vehicleModel • $vehicleNo',
                        style: const TextStyle(
                          fontSize: 13,
                          color: panelTextGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFE082), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        ratingVal.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: panelTextDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: panelDivider),
            const SizedBox(height: 14),

            // Call + Message buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionButton(
                  icon: Icons.phone,
                  label: 'Call',
                  onTap: () async {
                    if (driverPhone.isNotEmpty) {
                      final uri = Uri.parse('tel:$driverPhone');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not open phone dialer')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 48),
                _actionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  onTap: _openChatScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA8DFC0), width: 1),
            ),
            child: Icon(icon, color: const Color(0xFF27AE60), size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A8A8A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpSosRow(
    BuildContext context,
    bool showOtp,
    bool expectOtp,
    String tripStatus,
  ) {
    const Color panelOrange = Color(0xFFE84917);
    const Color panelTextDark = Color(0xFF1A1A1A);
    const Color panelCardBg = Color(0xFFFFFFFF);

    Widget otpCardContent;
    if (tripStatus == 'started' || tripStatus == 'completed') {
      otpCardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF27AE60), size: 16),
              SizedBox(width: 6),
              Text(
                'Trip Status',
                style: TextStyle(
                  fontSize: 12,
                  color: panelTextDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            'Verified\n& Active',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF27AE60),
              height: 1.2,
            ),
          ),
        ],
      );
    } else if (showOtp && _otpCode != null) {
      otpCardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_outline_rounded, color: panelTextDark, size: 16),
              SizedBox(width: 6),
              Text(
                'OTP for Driver',
                style: TextStyle(
                  fontSize: 12,
                  color: panelTextDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _otpCode!,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: panelOrange,
              letterSpacing: 3,
            ),
          ),
        ],
      );
    } else if (expectOtp) {
      otpCardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: panelTextDark, size: 16),
              SizedBox(width: 6),
              Text(
                'OTP for Driver',
                style: TextStyle(
                  fontSize: 12,
                  color: panelTextDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(panelOrange),
            ),
          ),
        ],
      );
    } else {
      otpCardContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lock_outline_rounded, color: panelTextDark, size: 16),
              SizedBox(width: 6),
              Text(
                'OTP for Driver',
                style: TextStyle(
                  fontSize: 12,
                  color: panelTextDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '--',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: panelOrange,
              letterSpacing: 3,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              height: 80,
              decoration: BoxDecoration(
                color: (tripStatus == 'started' || tripStatus == 'completed')
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFF0EB),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: otpCardContent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_tripId != null) {
                  try {
                    await ApiService.raiseSOS(_tripId!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🚨 SOS Alert Raised! Support notified.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to raise SOS')),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'SOS Help',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Emergency\nassistance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    const Color panelOrange = Color(0xFFE84917);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cancel Ride?'),
              content: const Text('Are you sure you want to cancel this ride request?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _cancelCurrentRide(closeAfterCancel: true);
                  },
                  child: const Text(
                    'Yes, Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: panelOrange, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: panelOrange.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cancel_outlined, color: panelOrange, size: 22),
              SizedBox(width: 10),
              Text(
                'Cancel Ride',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: panelOrange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getVehicleLabel(String type) {
    switch (type) {
      case 'ac_cab':
        return 'AC Cab';
      case 'non_ac_cab':
        return 'Non-AC Cab';
      case 'bike':
        return 'Bike';
      case 'auto':
        return 'Auto';
      case 'toto':
        return 'Toto';
      default:
        return 'Ride';
    }
  }

  String _getVehicleEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'ac_cab':
        return '🚖';
      case 'non_ac_cab':
        return '🚕';
      case 'bike':
        return '🏍️';
      case 'auto':
        return '🛺';
      case 'toto':
        return '🛺';
      case 'ambulance':
        return '🚑';
      default:
        return '🚖';
    }
  }

  String _getVehicleTag(String type) {
    switch (type.toLowerCase()) {
      case 'ac_cab':
        return 'Comfortable';
      case 'non_ac_cab':
        return 'Budget';
      case 'bike':
        return 'Fastest';
      case 'auto':
        return 'Eco';
      case 'toto':
        return 'Local';
      default:
        return 'Comfortable';
    }
  }
}

// ── Map grid painter ──
class _MapGridPainter extends CustomPainter {
  final Color accentColor;
  const _MapGridPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    final roadPaint = Paint()
      ..color = const Color(0xFFE8E0D5)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.3, size.width, 16), roadPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.58, size.width, 14), roadPaint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.22, 0, 16, size.height), roadPaint);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.52, 0, 18, size.height), roadPaint);

    final routePaint = Paint()
      ..color = accentColor.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.35, size.height * 0.3)
      ..cubicTo(size.width * 0.45, size.height * 0.35, size.width * 0.55,
          size.height * 0.45, size.width * 0.65, size.height * 0.58);
    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
//  MAIN HOME SCREEN
// ══════════════════════════════════════════════════════════════
class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  String _activeTab = 'home';
  ({ServiceItem service, String prefilledDest, bool genericMode})? _activeScreen;
  ({String title, List<ServiceItem> items})? _seeAll;
  final _whereToKey = GlobalKey<_WhereToScreenState>();
  int _promoIdx = 0;
  String _greeting = 'Good morning';
  String _currentLocation = 'Connaught Place, New Delhi';
  bool _showLocationModal = false;
  Timer? _promoTimer;
  Timer? _activeTripTimer;
  late PageController _promoPageCtrl;
  int? _restoredTripId;

  @override
  void initState() {
    super.initState();
    _promoPageCtrl = PageController(viewportFraction: 0.85);
    final h = DateTime.now().hour;
    if (h < 12)
      _greeting = 'Good morning';
    else if (h < 17)
      _greeting = 'Good afternoon';
    else
      _greeting = 'Good evening';

    _promoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() {
        _promoIdx = (_promoIdx + 1) % promos.length;
      });
      if (_promoPageCtrl.hasClients) {
        _promoPageCtrl.animateToPage(_promoIdx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    });

    // Refresh profile details (including profile picture URL) from server on startup
    _refreshProfileDetails();

    _checkActiveTrip();
    _activeTripTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkActiveTrip();
    });
  }

  /// Fetch the latest profile data from the server and persist it locally.
  /// This ensures the S3 profile picture URL survives app restarts.
  Future<void> _refreshProfileDetails() async {
    try {
      final res = await ApiService.getMe();
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        // Try every known key the backend might use for the profile picture URL
        final picUrl = (
          data['profile_picture_url'] ??
          data['profile_pic_url'] ??
          data['profile_pic'] ??
          data['avatar_url'] ??
          ''
        ).toString();
        if (picUrl.isNotEmpty) {
          await AuthService.updateProfilePic(picUrl);
        }
        // Also refresh name/phone in case they changed
        if (data['full_name'] != null) {
          await AuthService.saveSession({
            'access_token': AuthService.token,
            'role': AuthService.role,
            'full_name': data['full_name'],
            'phone': data['phone'] ?? AuthService.phone,
            'user_id': data['user_id'] ?? AuthService.userId,
            'wallet_balance': data['wallet_balance'] ?? AuthService.walletBalance,
            'kcoin_balance': data['kcoin_balance'] ?? AuthService.kcoinBalance,
            'rider_id': data['rider_id'] ?? AuthService.riderId,
            'profile_pic': picUrl.isNotEmpty ? picUrl : AuthService.profilePic,
          });
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Profile refresh error: $e');
    }
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _activeTripTimer?.cancel();
    _promoPageCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkActiveTrip() async {
    try {
      final res = await ApiService.getActiveTrip();
      if (res['success'] == true && res['data']?['active_trip'] != null) {
        final trip = res['data']['active_trip'];
        final serviceItem = services.firstWhere(
          (s) => s.vehicleType == trip['vehicle_type'] || s.tag == 'Standard',
          orElse: () => services.first,
        );
        final tripId = (trip['id'] as num?)?.toInt();
        if (mounted && (_activeScreen == null || _restoredTripId != tripId)) {
          setState(() {
            _restoredTripId = tripId;
            _activeScreen = (
              service: serviceItem,
              prefilledDest: trip['drop_address'] ?? '',
              genericMode: false,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Check active trip error: $e');
    }
  }

  final _rideServices = services.where((s) => s.category == 'ride').toList();
  final _deliveryServices =
      services.where((s) => s.category == 'delivery').toList();
  late final _gridRideServices =
      _rideServices.where((s) => s.id != 10).toList();
  late final _evRide = services.firstWhere((s) => s.id == 10);

  void _openService(ServiceItem service, {String prefilledDest = '', bool genericMode = false}) {
    setState(
        () => _activeScreen = (service: service, prefilledDest: prefilledDest, genericMode: genericMode));
  }

  void _showNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 40),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications 🔔',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ApiService.markAllRead();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All marked as read!')),
                        );
                      } catch (_) {}
                    },
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 12,
                        color: kOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: ApiService.getNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: kOrange),
                      );
                    }
                    final list =
                        snapshot.data?['data']?['notifications'] as List?;
                    if (snapshot.hasError || list == null || list.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('📣', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 12),
                            Text(
                              'No new notifications',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: kMuted,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final notif = list[index];
                        final isUnread = notif['is_read'] != true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUnread ? kOrangeLight : kGray,
                            borderRadius: BorderRadius.circular(14),
                            border: isUnread
                                ? Border.all(
                                    color: kOrange.withOpacity(0.2), width: 1.5)
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUnread ? '🔵' : '⚪',
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notif['title'] ?? 'Notification',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isUnread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: kDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif['message'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickProfileImage() async {
    // Show a premium bottom sheet to choose Camera or Gallery
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 12 : 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Update Profile Photo',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how you want to upload your photo',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 13,
                color: Colors.white.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                // Camera option
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 32),
                          SizedBox(height: 10),
                          Text(
                            'Camera',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Take a new photo',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Gallery option
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_rounded,
                              color: Colors.white.withOpacity(0.9), size: 32),
                          const SizedBox(height: 10),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose from gallery',
                            style: TextStyle(
                              fontFamily: 'Sora',
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cancel button
            GestureDetector(
              onTap: () => Navigator.pop(context, null),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (source == null) return; // User cancelled

    try {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        // Show high-end loading snackbar
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Uploading profile picture... 📸',
                    style: const TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            duration: const Duration(seconds: 4),
            backgroundColor: kDark.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        final res =
            await ApiService.uploadProfilePicture(File(pickedFile.path));

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (res['success']) {
          // Extract the permanent S3 URL — try every key the backend might return
          final responseData = res['data'] as Map<String, dynamic>? ?? {};
          final url = (
            responseData['profile_picture_url'] ??
            responseData['profile_pic_url'] ??
            responseData['profile_pic'] ??
            responseData['avatar_url'] ??
            responseData['url'] ??
            ''
          ).toString();
          // Persist the S3 URL so it survives app restarts
          if (url.isNotEmpty) {
            await AuthService.updateProfilePic(url);
          }
          // Re-fetch from server to confirm the saved URL and keep local cache in sync
          _refreshProfileDetails();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile picture uploaded successfully! 🎉',
                  style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              backgroundColor: kOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${res['error']}',
                  style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFFE53935),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e',
              style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildWalletTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Wallet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Wallet Balance',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, dynamic>>(
                future: ApiService.getWalletBalance(),
                builder: (ctx, snap) {
                  final bal = snap.data?['data']?['wallet_balance'] ?? 0.0;
                  return Text('₹${bal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white));
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFFFF6B35).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('K Coins',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 4),
                    FutureBuilder<Map<String, dynamic>>(
                      future: ApiService.getMe(),
                      builder: (ctx, snap) {
                        final coins = snap.data?['kcoin_balance'] ??
                            AuthService.kcoinBalance;
                        return Text('$coins coins',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFF6B35)));
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text('100 coins = ₹10 discount on next ride',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('How to earn K Coins?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          _coinTip('🚗', 'Complete a ride', 'Every ₹10 = 1 K Coin'),
          _coinTip('🎁', 'Special offers', 'Watch for bonus events'),
        ],
      ),
    );
  }

  Widget _coinTip(String icon, String title, String sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E))),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _profileOptionTile({
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
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: kMuted)),
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
              final referralCode = data?['referral_code']?.toString() ??
                  'KRIDE50'; // standard fallback

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

                    const Text(
                      'Refer a Friend & Earn! 👥',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: kDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'Share your unique referral code with friends. When they register and take their first ride, both of you will receive bonus coins! 🪙',
                      style: TextStyle(
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
                          const Text(
                            'YOUR REFERRAL CODE',
                            style: TextStyle(
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
                              style: const TextStyle(
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
                                  style: const TextStyle(
                                      fontFamily: 'Sora',
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
                        label: const Text(
                          'Copy Referral Code',
                          style: TextStyle(
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

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [kOrange, kOrangeDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          boxShadow: [
                            BoxShadow(
                                color: kOrange.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: ClipOval(
                          child: AuthService.profilePic.isNotEmpty
                              ? (AuthService.profilePic.startsWith('http')
                                  ? Image.network(
                                      AuthService.profilePic,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                              AuthService.name.isNotEmpty
                                                  ? AuthService.name[0]
                                                      .toUpperCase()
                                                  : 'R',
                                              style: const TextStyle(
                                                  fontSize: 40,
                                                  fontWeight: FontWeight.w800,
                                                  color: kWhite))),
                                    )
                                  : Image.file(
                                      File(AuthService.profilePic),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                              AuthService.name.isNotEmpty
                                                  ? AuthService.name[0]
                                                      .toUpperCase()
                                                  : 'R',
                                              style: const TextStyle(
                                                  fontSize: 40,
                                                  fontWeight: FontWeight.w800,
                                                  color: kWhite))),
                                    ))
                              : Center(
                                  child: Text(
                                      AuthService.name.isNotEmpty
                                          ? AuthService.name[0].toUpperCase()
                                          : 'R',
                                      style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w800,
                                          color: kWhite))),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: kOrange,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ]),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(AuthService.name,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kDark)),
                const SizedBox(height: 4),
                Text('+91 ${AuthService.phone}',
                    style: const TextStyle(fontSize: 14, color: kMuted)),
                const SizedBox(height: 32),
                _profileOptionTile(
                  icon: '👥',
                  title: 'Refer a Friend',
                  subtitle: 'Get bonus coins on every successful referral',
                  onTap: _showReferralBottomSheet,
                ),
                _profileOptionTile(
                  icon: '💬',
                  title: 'Support & Help',
                  subtitle: 'Connect with support or browse FAQs',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => Container(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom + 8 : 20),
                        constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.75),
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
                              const Text('Contact Support 💬',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: kDark)),
                              const SizedBox(height: 12),
                              const Text(
                                  'Need assistance with your ride or delivery?',
                                  style: TextStyle(fontSize: 14, color: kMuted),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 24),
                              _profileOptionTile(
                                icon: '📞',
                                title: 'Call Support Helpline',
                                subtitle: 'Instant phone support (24/7)',
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Calling Helpline: +91 1800-KRIDE 📞')));
                                },
                              ),
                              _profileOptionTile(
                                icon: '🟢',
                                title: 'Chat on WhatsApp',
                                subtitle: 'Get support via WhatsApp chat',
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Opening WhatsApp Support Chat 🟢')));
                                },
                              ),
                              _profileOptionTile(
                                icon: '✉️',
                                title: 'Email support',
                                subtitle: 'support@kride.app',
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Opening email compose ✉️')));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
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
                      backgroundColor: const Color(0xFFFFF0F0),
                      foregroundColor: const Color(0xFFE53935),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Log Out',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _activeTab = 'profile');
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$_greeting, ',
                        style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                      ),
                      const Text('👋', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AuthService.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                      fontFamily: 'Sora',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _buildNotificationBell(),
                const SizedBox(width: 12),
                _buildUserAvatar(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildNotificationBell() {
    return GestureDetector(
      onTap: _showNotificationsBottomSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, size: 28, color: Colors.black87),
          Positioned(
            top: 1,
            right: 1,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: kOrange,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar() {
    return GestureDetector(
      onTap: () => setState(() => _activeTab = 'profile'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kOrange.withValues(alpha: 0.3), width: 2),
          color: const Color(0xFFFFD9B0),
        ),
        child: ClipOval(
          child: AuthService.profilePic.isNotEmpty
              ? (AuthService.profilePic.startsWith('http')
                  ? Image.network(
                      AuthService.profilePic,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 26, color: Color(0xFFBF6020)),
                    )
                  : Image.file(
                      File(AuthService.profilePic),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 26, color: Color(0xFFBF6020)),
                    ))
              : const Icon(Icons.person, size: 26, color: Color(0xFFBF6020)),
        ),
      ),
    );
  }



  Widget _buildNewLocationCard() {
    return GestureDetector(
      onTap: () => _openService(_rideServices[1], genericMode: true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: const BoxDecoration(
                    color: kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Current location',
                    style: TextStyle(fontSize: 14.5, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.my_location_rounded, color: kOrange, size: 19),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  Column(
                    children: List.generate(
                      2,
                      (i) => Container(
                        width: 2,
                        height: 2,
                        margin: const EdgeInsets.symmetric(vertical: 1.0),
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: Divider(color: Colors.grey.shade200, height: 8)),
                ],
              ),
            ),
            Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: kOrange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Where to?',
                    style: TextStyle(fontSize: 14.5, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewRideCategoryRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildRideCategoryCard(
              label: 'Car & Bike',
              bgColor: kOrangeBg,
              arrowColor: kOrange,
              vehicleImage: const SizedBox(
                width: 68,
                height: 54,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: ServiceIconWidget(icon: 'ac_cab', size: 42),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: ServiceIconWidget(icon: 'bike', size: 42),
                    ),
                  ],
                ),
              ),
              onTap: () {
                final items = _rideServices.where((s) => [1, 2, 3].contains(s.id)).toList();
                setState(() => _seeAll = (title: 'Car & Bike', items: items));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRideCategoryCard(
              label: 'Auto & Toto',
              bgColor: kGreenBg,
              arrowColor: kGreenArrow,
              vehicleImage: const SizedBox(
                width: 68,
                height: 54,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: ServiceIconWidget(icon: 'auto', size: 42),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: ServiceIconWidget(icon: 'toto', size: 42),
                    ),
                  ],
                ),
              ),
              onTap: () {
                final items = _rideServices.where((s) => [4, 5].contains(s.id)).toList();
                setState(() => _seeAll = (title: 'Auto & Toto', items: items));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRideCategoryCard(
              label: 'Ambulance',
              bgColor: kPinkBg,
              arrowColor: kPinkArrow,
              vehicleImage: const ServiceIconWidget(icon: 'ambulance', size: 50),
              onTap: () {
                final service = services.firstWhere((s) => s.id == 6);
                _openService(service);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCategoryCard({
    required String label,
    required Color bgColor,
    required Color arrowColor,
    required Widget vehicleImage,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Center(
              child: Container(
                height: 54,
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: vehicleImage,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_rounded, size: 11, color: arrowColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewServicesRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildServiceCard(
              iconKey: 'parcel',
              label: 'Parcel',
              onTap: () => _openService(services.firstWhere((s) => s.id == 8)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildServiceCard(
              iconKey: 'medicine',
              label: 'Medicine',
              onTap: () => _openService(services.firstWhere((s) => s.id == 9)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildServiceCard(
              iconKey: 'food',
              label: 'Food',
              onTap: () => _openService(services.firstWhere((s) => s.id == 7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String iconKey,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: kOrangeBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kOrange, width: 1.2),
        ),
        child: Row(
          children: [
            ServiceIconWidget(icon: iconKey, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewOtherOptionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildOtherOptionCard(
              iconWidget: Image.asset(
                'assets/images/schdule ride.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.calendar_month_outlined, color: kOrange, size: 28),
              ),
              label: 'Schedule',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule Ride feature coming soon!')),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildOtherOptionCard(
              iconWidget: Image.asset(
                'assets/images/intercity.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.route_rounded, color: kOrange, size: 28),
              ),
              label: 'Intercity',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Intercity rides coming soon!')),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildOtherOptionCard(
              iconWidget: Image.asset(
                'assets/images/corporate.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.business_outlined, color: Colors.grey, size: 28),
              ),
              label: 'Corporate',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Corporate profile feature coming soon!')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherOptionCard({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: kOrangeBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kOrange, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: iconWidget,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewEVBanner() {
    return GestureDetector(
      onTap: () => _openService(services.firstWhere((s) => s.id == 10)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 110,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/ev car banner.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Text('🚗⚡', style: TextStyle(fontSize: 32))),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kGreenText,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Explore EV',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_activeScreen != null) {
          await _whereToKey.currentState?.handleBackPress();
          return false;
        }
        if (_activeTab != 'home') {
          setState(() => _activeTab = 'home');
          return false;
        }
        return false;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: kWhite,
          body: Stack(
            children: [
              if (_activeTab == 'home')
                SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNewTopBar(),
                        const SizedBox(height: 32),
                        _buildNewLocationCard(),
                        const SizedBox(height: 18),
                        _buildNewRideCategoryRow(),
                        const SizedBox(height: 22),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Our Services',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNewServicesRow(),
                        const SizedBox(height: 26),
                        _buildNewEVBanner(),
                        const SizedBox(height: 26),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Other Options',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildNewOtherOptionsRow(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                )
              else if (_activeTab == 'profile')
                SafeArea(bottom: false, child: _buildProfileTab())
              else if (_activeTab == 'wallet')
                SafeArea(bottom: false, child: _buildWalletTab())
              else if (_activeTab == 'activity')
                _RiderActivityTab(),

              // Modals & Screens
              if (_showLocationModal)
                Positioned.fill(
                    child: LocationModal(
                        current: _currentLocation,
                        onSelect: (loc) => setState(() {
                              _currentLocation = loc;
                              _showLocationModal = false;
                            }),
                        onClose: () =>
                            setState(() => _showLocationModal = false))),

              if (_seeAll != null)
                Positioned.fill(
                    child: SeeAllModal(
                        title: _seeAll!.title,
                        items: _seeAll!.items,
                        onSelect: _openService,
                        onClose: () => setState(() => _seeAll = null))),

              if (_activeScreen != null)
                Positioned.fill(
                    child: WhereToScreen(
                  key: _whereToKey,
                  service: _activeScreen!.service,
                  prefilledDest: _activeScreen!.prefilledDest,
                  activeTripId: _restoredTripId,
                  genericMode: _activeScreen!.genericMode,
                  onBack: () {
                    setState(() {
                      _activeScreen = null;
                      _restoredTripId = null;
                    });
                    _checkActiveTrip();
                  },
                )),
            ],
          ),
          bottomNavigationBar: (_activeScreen == null && !_showLocationModal && _seeAll == null)
              ? Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      )
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: _BottomNav(
                      currentIndex: (() {
                        switch (_activeTab) {
                          case 'home':
                            return 0;
                          case 'activity':
                            return 1;
                          case 'wallet':
                            return 2;
                          case 'profile':
                            return 3;
                          default:
                            return 0;
                        }
                      })(),
                      onTap: (index) {
                        setState(() {
                          switch (index) {
                            case 0:
                              _activeTab = 'home';
                              break;
                            case 1:
                              _activeTab = 'activity';
                              break;
                            case 2:
                              _activeTab = 'wallet';
                              break;
                            case 3:
                              _activeTab = 'profile';
                              break;
                          }
                        });
                      },
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  RIDER ACTIVITY TAB
// ══════════════════════════════════════════════════════════════
class _RiderActivityTab extends StatefulWidget {
  const _RiderActivityTab();

  @override
  State<_RiderActivityTab> createState() => _RiderActivityTabState();
}

class _RiderActivityTabState extends State<_RiderActivityTab> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final res = await ApiService.getRiderHistory(limit: 50);
      if (res['success'] == true) {
        final data = res['data'];
        final tripsList = (data['trips'] ?? data['results'] ?? data ?? []) as List;
        setState(() {
          _trips = tripsList.map((t) => Map<String, dynamic>.from(t)).toList();
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    if (status == 'completed') return const Color(0xFF2E7D32);
    if (status == 'cancelled') return const Color(0xFFD32F2F);
    return kMuted;
  }

  Widget _badge(String? status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(
        (status ?? '').replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _tripCard(Map<String, dynamic> trip) {
    final fare = trip['actual_fare'] ?? trip['estimated_fare'] ?? 0;
    final dist = trip['distance_km'] ?? '';
    final code = trip['trip_code'] ?? '';
    final pickup = trip['pickup_address'] ?? '';
    final drop = trip['drop_address'] ?? '';
    final status = (trip['status'] ?? '').toString();
    final rawDate = trip['created_at'] ?? trip['updated_at'] ?? '';
    String dateLabel = '';
    if (rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate).toLocal();
        dateLabel =
            '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          Text('#$code',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kMuted)),
          _badge(status),
        ]),
        if (dateLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(dateLabel,
              style: const TextStyle(fontSize: 11, color: kMuted)),
        ],
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF2E7D32))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: kDark))),
        ]),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                  color: kOrange,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(drop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: kMuted))),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('₹$fare',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kOrange)),
          if (dist.toString().isNotEmpty)
            Text('$dist km',
                style: const TextStyle(fontSize: 12, color: kMuted)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Activity',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kDark)),
              if (!_loading)
                GestureDetector(
                  onTap: _loadHistory,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: kOrangeLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.refresh_rounded,
                        color: kOrange, size: 18),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: kOrange))
              : _hasError
                  ? Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          const Text('Could not load trips',
                              style: TextStyle(color: kMuted, fontSize: 15)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadHistory,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kOrange,
                                foregroundColor: kWhite),
                            child: const Text('Retry'),
                          )
                        ]))
                  : _trips.isEmpty
                      ? const Center(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              Text('🚗', style: TextStyle(fontSize: 40)),
                              SizedBox(height: 12),
                              Text('No trips yet',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: kDark)),
                              SizedBox(height: 4),
                              Text('Your ride history will appear here',
                                  style: TextStyle(
                                      fontSize: 13, color: kMuted)),
                            ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: _trips.length,
                          itemBuilder: (_, i) => _tripCard(_trips[i]),
                        ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  RECENT PLACE TILE
// ══════════════════════════════════════════════════════════════
class _RecentPlaceTile extends StatefulWidget {
  final PlaceItem place;
  final VoidCallback onTap;
  const _RecentPlaceTile({required this.place, required this.onTap});

  @override
  State<_RecentPlaceTile> createState() => _RecentPlaceTileState();
}

class _RecentPlaceTileState extends State<_RecentPlaceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: _hovered ? kOrangeLight : kGray,
            borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]),
                child: Center(
                    child: Text(widget.place.icon,
                        style: const TextStyle(fontSize: 18)))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.place.label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kDark)),
                  Text(widget.place.sub,
                      style: const TextStyle(fontSize: 11.5, color: kMuted)),
                ])),
            const Text('›', style: TextStyle(color: kMuted, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}



// BOTTOM NAVIGATION BAR
// ─────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.directions_car_rounded, label: 'Rides'),
      _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Wallet'),
      _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.white,
        selectedItemColor: kOrange,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: items
            .map(
              (n) => BottomNavigationBarItem(
                icon: Icon(n.icon, size: 24),
                label: n.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
