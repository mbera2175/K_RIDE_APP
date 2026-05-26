import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../auth/role_selection_screen.dart';
// ── Constants ──
const kOrange = Color(0xFFFF6B00);
const kOrangeLight = Color(0xFFFFF3E8);
const kOrangeDark = Color(0xFFE55A00);
const kWhite = Color(0xFFFFFFFF);
const kGray = Color(0xFFF6F6F6);
const kDark = Color(0xFF1A1A1A);
const kMuted = Color(0xFF9E9E9E);

// ── Data models ──
class ServiceItem {
  final int id;
  final String name;
  final String icon; // emoji or "toto"
  final String category;
  final String? tag;
  final Color color;
  final Color accent;
  final bool bikeOnly;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    this.tag,
    required this.color,
    required this.accent,
    required this.bikeOnly,
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
  ServiceItem(id: 1, name: 'Cab AC',     icon: '🚖', category: 'ride',     tag: null,        color: kOrangeLight, accent: kOrange,           bikeOnly: false),
  ServiceItem(id: 2, name: 'Cab Non-AC', icon: '🚕', category: 'ride',     tag: 'Budget',    color: kOrangeLight, accent: kOrange,           bikeOnly: false),
  ServiceItem(id: 3, name: 'Bike',       icon: '🏍️', category: 'ride',     tag: 'Fastest',   color: kOrangeLight, accent: kOrange,           bikeOnly: false),
  ServiceItem(id: 4, name: 'Three Wheeler', icon: '🛺', category: 'ride',   tag: 'Auto/Toto', color: kOrangeLight, accent: kOrange,           bikeOnly: false),
  ServiceItem(id: 6, name: 'Ambulance',  icon: '🚑', category: 'ride',     tag: 'Emergency', color: Color(0xFFFFF0F0), accent: Color(0xFFE53935), bikeOnly: false),
  ServiceItem(id: 7, name: 'Food',       icon: '🍱', category: 'delivery', tag: 'Bike only', color: kOrangeLight, accent: kOrange,           bikeOnly: true),
  ServiceItem(id: 8, name: 'Parcel',     icon: '📦', category: 'delivery', tag: 'Bike only', color: Color(0xFFF3F0FF), accent: Color(0xFF5E35B1), bikeOnly: true),
  ServiceItem(id: 9, name: 'Medicine',   icon: '💊', category: 'delivery', tag: 'Bike only', color: Color(0xFFF0F8FF), accent: Color(0xFF0277BD), bikeOnly: true),
];

const paymentMethods = [
  PaymentMethod(id: 'cash',   icon: '💵', label: 'Cash',     sub: 'Pay driver directly'),
  PaymentMethod(id: 'upi',    icon: '📱', label: 'UPI',      sub: 'GPay, PhonePe, Paytm'),
  PaymentMethod(id: 'card',   icon: '💳', label: 'Card',     sub: 'Credit / Debit card'),
  PaymentMethod(id: 'wallet', icon: '👛', label: 'K Wallet', sub: 'Balance: ₹240'),
];

const promos = [
  PromoItem(title: 'First ride free!',  sub: 'Use code KRIDE1',     gradientColors: [kOrange, kOrangeDark]),
  PromoItem(title: 'Food delivery',     sub: 'Up to 40% off today', gradientColors: [Color(0xFF2E7D32), Color(0xFF43A047)]),
  PromoItem(title: 'Refer & Earn',      sub: '₹50 per referral',    gradientColors: [Color(0xFF5E35B1), Color(0xFF7B1FA2)]),
];

const recentPlaces = [
  PlaceItem(icon: '🏠', label: 'Home',        sub: 'Sector 15, Noida'),
  PlaceItem(icon: '💼', label: 'Office',       sub: 'Cyber City, Gurugram'),
  PlaceItem(icon: '🛍️', label: 'Select Mall', sub: 'Saket, Delhi'),
  PlaceItem(icon: '✈️', label: 'Airport',      sub: 'IGI Terminal 3, Delhi'),
];

const savedLocations = [
  PlaceItem(icon: '🏠', label: 'Home',        sub: 'Sector 15, Noida'),
  PlaceItem(icon: '💼', label: 'Office',       sub: 'Cyber City, Gurugram'),
  PlaceItem(icon: '✈️', label: 'Airport',      sub: 'IGI Terminal 3, Delhi'),
  PlaceItem(icon: '🛍️', label: 'Select Mall', sub: 'Saket, Delhi'),
];


// ══════════════════════════════════════════════════════════════
//  TOTO ICON  (Custom painter for the green electric rickshaw)
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

    // Background rounded rect
    p.color = const Color(0xFFFFF7F0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(28 * s)), p);

    // Border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFFFFD7B8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6 * s, 6 * s, 116 * s, 116 * s), Radius.circular(24 * s)), border);

    final stroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);

    // Roof
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

    // Windshield
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

    // Body
    p.color = const Color(0xFF20C05C);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s), Radius.circular(8 * s)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s), Radius.circular(8 * s)), stroke2);

    // Front
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

    // Seats
    p.color = const Color(0xFF2A2A2A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(48 * s, 57 * s, 18 * s, 12 * s), Radius.circular(3 * s)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(70 * s, 57 * s, 18 * s, 12 * s), Radius.circular(3 * s)), p);

    // Frame lines
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);
    canvas.drawLine(Offset(46 * s, 34 * s), Offset(46 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(68 * s, 34 * s), Offset(68 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(90 * s, 38 * s), Offset(90 * s, 88 * s), framePaint);

    // Headlight
    p.color = const Color(0xFFFFF3B0);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, p);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, stroke2);

    // Wheels
    void drawWheel(double cx, double cy, double r) {
      p.color = const Color(0xFF222222);
      canvas.drawCircle(Offset(cx * s, cy * s), r * s, p);
      p.color = const Color(0xFFD9D9D9);
      canvas.drawCircle(Offset(cx * s, cy * s), 5 * s, p);
    }
    drawWheel(42, 95, 10);
    drawWheel(89, 95, 10);
    drawWheel(24, 92, 11);

    // Shadow
    p.color = Colors.black.withOpacity(0.08);
    canvas.drawOval(Rect.fromCenter(center: Offset(64 * s, 108 * s), width: 68 * s, height: 8 * s), p);
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

    // Background rounded rect
    p.color = const Color(0xFFFFF7F0);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(28 * s)), p);

    // Border
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFFFFD7B8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6 * s, 6 * s, 116 * s, 116 * s), Radius.circular(24 * s)), border);

    final stroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);

    // Roof
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

    // Windshield
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

    // Body
    p.color = const Color(0xFFFFCC00);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s), Radius.circular(8 * s)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(35 * s, 52 * s, 60 * s, 36 * s), Radius.circular(8 * s)), stroke2);

    // Front
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

    // Seats
    p.color = const Color(0xFF2A2A2A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(48 * s, 57 * s, 18 * s, 12 * s), Radius.circular(3 * s)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(70 * s, 57 * s, 18 * s, 12 * s), Radius.circular(3 * s)), p);

    // Frame lines
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = const Color(0xFF222222);
    canvas.drawLine(Offset(46 * s, 34 * s), Offset(46 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(68 * s, 34 * s), Offset(68 * s, 88 * s), framePaint);
    canvas.drawLine(Offset(90 * s, 38 * s), Offset(90 * s, 88 * s), framePaint);

    // Headlight
    p.color = const Color(0xFFFFF3B0);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, p);
    canvas.drawCircle(Offset(28 * s, 67 * s), 6 * s, stroke2);

    // Wheels
    void drawWheel(double cx, double cy, double r) {
      p.color = const Color(0xFF222222);
      canvas.drawCircle(Offset(cx * s, cy * s), r * s, p);
      p.color = const Color(0xFFD9D9D9);
      canvas.drawCircle(Offset(cx * s, cy * s), 5 * s, p);
    }
    drawWheel(42, 95, 10);
    drawWheel(89, 95, 10);
    drawWheel(24, 92, 11);

    // Shadow
    p.color = Colors.black.withOpacity(0.08);
    canvas.drawOval(Rect.fromCenter(center: Offset(64 * s, 108 * s), width: 68 * s, height: 8 * s), p);
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
    if (icon == 'three_wheeler') return AutoIcon(size: size);
    if (icon == 'toto') return TotoIcon(size: size);
    return Text(icon, style: TextStyle(fontSize: size, fontFamily: 'Roboto', fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji']));
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
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: widget.service.color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: widget.service.accent.withOpacity(0.13), blurRadius: 14, offset: const Offset(0, 4))],
                    border: Border.all(color: widget.service.accent.withOpacity(0.13), width: 1.5),
                  ),
                  child: Center(child: ServiceIconWidget(icon: widget.service.icon, size: 30)),
                ),
                if (widget.service.tag != null)
                  Positioned(
                    top: -6, right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.service.accent,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [BoxShadow(color: widget.service.accent.withOpacity(0.33), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Text(widget.service.tag!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kWhite)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.service.name,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: kDark),
              textAlign: TextAlign.center,
              maxLines: 2,
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
      width: 220, height: 100,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: promo.gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                Text(promo.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kWhite)),
                const SizedBox(height: 4),
                Text(promo.sub, style: TextStyle(fontSize: 12, color: kWhite.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)),
  );
}

// ══════════════════════════════════════════════════════════════
//  LOCATION MODAL
// ══════════════════════════════════════════════════════════════
class LocationModal extends StatefulWidget {
  final String current;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;
  const LocationModal({super.key, required this.current, required this.onSelect, required this.onClose});

  @override
  State<LocationModal> createState() => _LocationModalState();
}

class _LocationModalState extends State<LocationModal> {
  final _controller = TextEditingController();
  bool _locating = false;

  void _useCurrentLocation() async {
    setState(() => _locating = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onSelect('Connaught Place, New Delhi');
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
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            decoration: const BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Set pickup location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kDark)),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close, size: 14, color: kDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5)),
                    child: Row(
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Type your location...', hintStyle: TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
                            style: const TextStyle(fontSize: 14, color: kDark),
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => widget.onSelect(_controller.text),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Set', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kWhite)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Current location button
                  GestureDetector(
                    onTap: _useCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: kOrange.withOpacity(0.2), width: 1.5)),
                      child: Row(
                        children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(_locating ? '⏳' : '🎯', style: const TextStyle(fontSize: 18)))),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_locating ? 'Detecting location...' : 'Use current location', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kOrange)),
                              const Text('Uses GPS to find you', style: TextStyle(fontSize: 12, color: kMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('SAVED PLACES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  ...savedLocations.map((loc) {
                    final full = '${loc.label}, ${loc.sub}';
                    final selected = widget.current == full;
                    return GestureDetector(
                      onTap: () => widget.onSelect(full),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: selected ? kOrangeLight : kGray, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(width: 40, height: 40, decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))]), child: Center(child: Text(loc.icon, style: const TextStyle(fontSize: 18)))),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
                                  Text(loc.sub, style: const TextStyle(fontSize: 12, color: kMuted)),
                                ],
                              ),
                            ),
                            if (selected) const Text('✓', style: TextStyle(color: kOrange, fontSize: 16)),
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
  const PaymentModal({super.key, required this.selected, required this.onSelect, required this.onClose});

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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kDark)),
                    GestureDetector(onTap: onClose, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close, size: 14))),
                  ],
                ),
                const SizedBox(height: 20),
                ...paymentMethods.map((pm) {
                  final sel = selected.id == pm.id;
                  return GestureDetector(
                    onTap: () { onSelect(pm); onClose(); },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? kOrangeLight : kGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sel ? kOrange : Colors.transparent, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))]), child: Center(child: Text(pm.icon, style: const TextStyle(fontSize: 22)))),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(pm.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kDark)),
                            Text(pm.sub, style: const TextStyle(fontSize: 12, color: kMuted)),
                          ])),
                          if (sel) const Text('✓', style: TextStyle(color: kOrange, fontSize: 20)),
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
  const SeeAllModal({super.key, required this.title, required this.items, required this.onSelect, required this.onClose});

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
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('All $title services', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kDark)),
                    GestureDetector(onTap: onClose, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close, size: 14))),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 0.9),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final s = items[i];
                      return GestureDetector(
                        onTap: () { onSelect(s); onClose(); },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(clipBehavior: Clip.none, children: [
                              Container(width: 64, height: 64, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: s.accent.withOpacity(0.13), width: 1.5), boxShadow: [BoxShadow(color: s.accent.withOpacity(0.13), blurRadius: 14, offset: const Offset(0, 4))]), child: Center(child: ServiceIconWidget(icon: s.icon, size: 30))),
                              if (s.tag != null)
                                Positioned(top: -6, right: -6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: s.accent, borderRadius: BorderRadius.circular(99)), child: Text(s.tag!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kWhite)))),
                            ]),
                            const SizedBox(height: 8),
                            Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kDark), textAlign: TextAlign.center),
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
  const BookingSuccessScreen({super.key, required this.service, required this.destination, required this.payment, required this.onDone});

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> with SingleTickerProviderStateMixin {
  int _countdown = 3;
  Timer? _timer;
  late AnimationController _pingController;
  late Animation<double> _pingAnim;

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _pingAnim = Tween(begin: 1.0, end: 2.0).animate(_pingController);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) { t.cancel(); widget.onDone(); }
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
          // Success ring with ping animation
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pingAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pingAnim.value,
                  child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kOrange.withOpacity(0.3), width: 3))),
                ),
              ),
              Container(
                width: 120, height: 120,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: kOrangeLight),
                child: Center(
                  child: Container(
                    width: 90, height: 90,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: kOrange),
                    child: const Center(child: Text('✓', style: TextStyle(fontSize: 40, color: kWhite))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Booking Confirmed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kDark), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Your ${widget.service.name} is being assigned', style: const TextStyle(fontSize: 14, color: kMuted), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          // Details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: widget.service.color, borderRadius: BorderRadius.circular(14)), child: Center(child: ServiceIconWidget(icon: widget.service.icon, size: 26))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.service.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kDark)),
                      const Text('Driver being assigned...', style: TextStyle(fontSize: 12, color: kMuted)),
                    ])),
                    Text('₹89', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: widget.service.accent)),
                  ],
                ),
                Divider(height: 32, color: Colors.grey.shade200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('DESTINATION', style: TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(widget.destination, style: const TextStyle(fontSize: 13, color: kDark, fontWeight: FontWeight.w600)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('PAYMENT', style: TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${widget.payment.icon} ${widget.payment.label}', style: const TextStyle(fontSize: 13, color: kDark, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Going to tracking in ${_countdown}s...', style: const TextStyle(fontSize: 13, color: kMuted)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: kWhite, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: kOrange.withOpacity(0.27)),
              child: const Text('Track my ride →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
  const WhereToScreen({super.key, required this.service, required this.prefilledDest, required this.onBack});

  @override
  State<WhereToScreen> createState() => _WhereToScreenState();
}

class _WhereToScreenState extends State<WhereToScreen> {
  final _pickupCtrl = TextEditingController(text: 'Connaught Place, New Delhi');
  late TextEditingController _destCtrl;
  String _step = 'input'; // 'input' | 'confirm'
  PaymentMethod _paymentMethod = paymentMethods[0];
  bool _booked = false;
  bool _showPaymentModal = false;

  final _quickDests = const [
    PlaceItem(icon: '🏠', label: 'Home',        sub: 'Sector 15, Noida'),
    PlaceItem(icon: '💼', label: 'Office',       sub: 'Cyber City, Gurugram'),
    PlaceItem(icon: '🛍️', label: 'Select Mall', sub: 'Saket, Delhi'),
    PlaceItem(icon: '✈️', label: 'Airport',      sub: 'IGI Terminal 3, Delhi'),
  ];

  @override
  void initState() {
    super.initState();
    _destCtrl = TextEditingController(text: widget.prefilledDest);
  }

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_booked) {
      return BookingSuccessScreen(
        service: widget.service,
        destination: _destCtrl.text,
        payment: _paymentMethod,
        onDone: widget.onBack,
      );
    }

    if (_step == 'confirm') return _buildConfirmStep();
    return _buildInputStep();
  }

  Widget _buildInputStep() {
    return Container(
      color: kWhite,
      child: Column(
        children: [
          Container(
            color: kWhite,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(onTap: widget.onBack, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('←', style: TextStyle(fontSize: 18))))),
                    const SizedBox(width: 14),
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: widget.service.color, borderRadius: BorderRadius.circular(10)), child: Center(child: ServiceIconWidget(icon: widget.service.icon, size: 20))),
                    const SizedBox(width: 10),
                    Text(widget.service.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kDark)),
                    if (widget.service.bikeOnly) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(99), border: Border.all(color: kOrange.withOpacity(0.2))),
                        child: const Text('🏍️ Bike only', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kOrange)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                // Pickup
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: kOrange.withOpacity(0.2), width: 1.5)),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: kOrange)),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _pickupCtrl, decoration: const InputDecoration(border: InputBorder.none, hintText: 'Pickup location'), style: const TextStyle(fontSize: 14, color: kDark))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Destination
                StatefulBuilder(
                  builder: (_, ss) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5)),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _destCtrl,
                            autofocus: true,
                            onChanged: (_) => ss(() {}),
                            decoration: InputDecoration(border: InputBorder.none, hintText: widget.service.category == 'delivery' ? 'Delivery address...' : 'Where to?'),
                            style: const TextStyle(fontSize: 14, color: kDark),
                          ),
                        ),
                        if (_destCtrl.text.isNotEmpty)
                          GestureDetector(onTap: () { _destCtrl.clear(); ss(() {}); }, child: const Text('✕', style: TextStyle(color: kMuted, fontSize: 16))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              children: [
                const Text('SAVED PLACES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                ..._quickDests.map((d) {
                  final full = '${d.label}, ${d.sub}';
                  return StatefulBuilder(
                    builder: (_, ss) => GestureDetector(
                      onTap: () { setState(() => _destCtrl.text = full); },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: _destCtrl.text.startsWith(d.label) ? kOrangeLight : kGray, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(width: 40, height: 40, decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))]), child: Center(child: Text(d.icon, style: const TextStyle(fontSize: 18)))),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
                              Text(d.sub, style: const TextStyle(fontSize: 11.5, color: kMuted)),
                            ])),
                            if (_destCtrl.text.startsWith(d.label)) const Text('✓', style: TextStyle(color: kOrange, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Continue button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            color: kWhite,
            child: StatefulBuilder(
              builder: (_, ss) {
                final hasText = _destCtrl.text.isNotEmpty;
                return ElevatedButton(
                  onPressed: hasText ? () => setState(() => _step = 'confirm') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasText ? widget.service.accent : const Color(0xFFEEEEEE),
                    foregroundColor: hasText ? kWhite : kMuted,
                    disabledBackgroundColor: const Color(0xFFEEEEEE),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: hasText ? 8 : 0,
                    shadowColor: widget.service.accent.withOpacity(0.27),
                  ),
                  child: SizedBox(width: double.infinity, child: Center(child: Text(hasText ? 'Find ${widget.service.name} →' : 'Enter a destination', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    return Stack(
      children: [
        Container(
          color: kWhite,
          child: Column(
            children: [
              // Map mockup
              Expanded(
                child: Container(
                  color: const Color(0xFFF8F4EF),
                  child: Stack(
                    children: [
                      CustomPaint(size: Size.infinite, painter: _MapGridPainter(accentColor: widget.service.accent)),
                      // Pickup pin
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.33 - 14,
                        top: MediaQuery.of(context).size.height * 0.28 - 28,
                        child: Transform.rotate(angle: -0.785, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: kOrange, borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14)), border: Border.all(color: kWhite, width: 3), boxShadow: [BoxShadow(color: kOrange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))]))),
                      ),
                      // Dest pin
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.64 - 13,
                        top: MediaQuery.of(context).size.height * 0.28 - 26,
                        child: Transform.rotate(angle: -0.785, child: Container(width: 26, height: 26, decoration: BoxDecoration(color: kDark, borderRadius: const BorderRadius.only(topLeft: Radius.circular(13), topRight: Radius.circular(13), bottomLeft: Radius.circular(13)), border: Border.all(color: kWhite, width: 3)))),
                      ),
                      // Car
                      Positioned(
                        left: MediaQuery.of(context).size.width * 0.22 - 18,
                        top: MediaQuery.of(context).size.height * 0.21,
                        child: Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: kWhite, border: Border.all(color: kOrange, width: 2), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 3))]), child: Center(child: ServiceIconWidget(icon: widget.service.icon, size: 18))),
                      ),
                      // Back button
                      Positioned(
                        top: 52, left: 16,
                        child: GestureDetector(onTap: () => setState(() => _step = 'input'), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))]), child: const Center(child: Text('←', style: TextStyle(fontSize: 18))))),
                      ),
                    ],
                  ),
                ),
              ),
              // Booking panel
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 32, offset: Offset(0, -8))]),
                child: Column(
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(99)))),
                    const SizedBox(height: 18),
                    // Service row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: widget.service.color, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))]), child: Center(child: ServiceIconWidget(icon: widget.service.icon, size: 26))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(widget.service.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kDark)),
                            Text('${widget.service.bikeOnly ? '🏍️ Bike rider · ' : ''}~12 min · 3.2 km', style: const TextStyle(fontSize: 12, color: kMuted)),
                          ])),
                          Text('₹89', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: widget.service.accent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Route
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: kOrange)), const SizedBox(width: 10), Expanded(child: Text(_pickupCtrl.text, style: const TextStyle(fontSize: 13, color: kDark)))]),
                          Container(margin: const EdgeInsets.only(left: 3), child: const Padding(padding: EdgeInsets.only(left: 0), child: SizedBox(height: 10))),
                          Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), Expanded(child: Text(_destCtrl.text, style: const TextStyle(fontSize: 13, color: kDark)))]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Payment selector
                    GestureDetector(
                      onTap: () => setState(() => _showPaymentModal = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5)),
                        child: Row(
                          children: [
                            Text(_paymentMethod.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_paymentMethod.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
                              Text(_paymentMethod.sub, style: const TextStyle(fontSize: 11, color: kMuted)),
                            ])),
                            const Text('Change →', style: TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    if (widget.service.tag == 'Emergency') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Text('🚨', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 8),
                          Expanded(child: Text('Nearest ambulance will be dispatched immediately', style: TextStyle(fontSize: 12, color: Color(0xFFE53935), fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Confirm button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {

  final body = {
    "pickup_address": _pickupCtrl.text,
    "drop_address": _destCtrl.text,

    "pickup_lat": 22.5726,
    "pickup_lng": 88.3639,

    "drop_lat": 22.5850,
    "drop_lng": 88.3950,

    "vehicle_type": widget.service.name.toLowerCase(),
    "payment_method": _paymentMethod.id,
  };

  try {

    final result = await ApiService.bookTrip(body);

    print("BOOK RESPONSE:");
    print(result);

    if (result["success"] == true) {

      setState(() => _booked = true);

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result["error"] ?? "Booking failed",
          ),
        ),
      );

    }

  } catch (e) {

    print("BOOK ERROR:");
    print(e);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Booking error: $e"),
      ),
    );

  }

},
                        style: ElevatedButton.styleFrom(backgroundColor: widget.service.accent, foregroundColor: kWhite, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: widget.service.accent.withOpacity(0.27)),
                        child: Text('Confirm ${widget.service.name} · ₹89', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
}

// ── Map grid painter ──
class _MapGridPainter extends CustomPainter {
  final Color accentColor;
  const _MapGridPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.grey.withOpacity(0.15)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    final roadPaint = Paint()..color = const Color(0xFFE8E0D5)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.3, size.width, 16), roadPaint);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.58, size.width, 14), roadPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.22, 0, 16, size.height), roadPaint);
    canvas.drawRect(Rect.fromLTWH(size.width * 0.52, 0, 18, size.height), roadPaint);

    final routePaint = Paint()..color = accentColor.withOpacity(0.8)..strokeWidth = 3..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(size.width * 0.35, size.height * 0.3)..cubicTo(size.width * 0.45, size.height * 0.35, size.width * 0.55, size.height * 0.45, size.width * 0.65, size.height * 0.58);
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
  ({ServiceItem service, String prefilledDest})? _activeScreen;
  ({String title, List<ServiceItem> items})? _seeAll;
  int _promoIdx = 0;
  String _greeting = 'Good morning';
  String _currentLocation = 'Connaught Place, New Delhi';
  bool _showLocationModal = false;
  Timer? _promoTimer;
  late PageController _promoPageCtrl;

  @override
  void initState() {
    super.initState();
    _promoPageCtrl = PageController(viewportFraction: 0.85);
    final h = DateTime.now().hour;
    if (h < 12) _greeting = 'Good morning';
    else if (h < 17) _greeting = 'Good afternoon';
    else _greeting = 'Good evening';

    _promoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      setState(() { _promoIdx = (_promoIdx + 1) % promos.length; });
      if (_promoPageCtrl.hasClients) {
        _promoPageCtrl.animateToPage(_promoIdx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoPageCtrl.dispose();
    super.dispose();
  }

  final _rideServices = services.where((s) => s.category == 'ride').toList();
  final _deliveryServices = services.where((s) => s.category == 'delivery').toList();

  void _openService(ServiceItem service, {String prefilledDest = ''}) {
    setState(() => _activeScreen = (service: service, prefilledDest: prefilledDest));
  }

  Widget _buildProfileTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: kOrange.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text(AuthService.name.isNotEmpty ? AuthService.name[0].toUpperCase() : 'R', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: kWhite))),
              ),
              const SizedBox(height: 16),
              Text(AuthService.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kDark)),
              const SizedBox(height: 4),
              Text('+91 ${AuthService.phone}', style: const TextStyle(fontSize: 14, color: kMuted)),
              const SizedBox(height: 40),
              
              // Logout button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await AuthService.logout();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF0F0),
                    foregroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: kWhite,
        body: Stack(
          children: [
            if (_activeTab == 'home')
              SafeArea(
                child: Column(
                  children: [
                  // ── Header ──
                  Container(
                    color: kWhite,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$_greeting 👋', style: const TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w500)),
                              RichText(text: TextSpan(
                                text: '${AuthService.name.split(' ').first} ',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kDark, fontFamily: 'Sora'),
                                children: [TextSpan(text: AuthService.name.split(' ').length > 1 ? AuthService.name.split(' ').sublist(1).join(' ') : '', style: const TextStyle(color: kOrange))],
                              )),
                            ]),
                            Row(children: [
                              Stack(children: [
                                Container(width: 42, height: 42, decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('🔔', style: TextStyle(fontSize: 18)))),
                                Positioned(top: 8, right: 9, child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: kOrange, border: Border.all(color: kWhite, width: 2)))),
                              ]),
                              const SizedBox(width: 10),
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(colors: [kOrange, kOrangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AuthService.profilePic.isNotEmpty
                                      ? Image.network(AuthService.profilePic, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(AuthService.name.isNotEmpty ? AuthService.name[0].toUpperCase() : 'U', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 16))))
                                      : Center(child: Text(AuthService.name.isNotEmpty ? AuthService.name[0].toUpperCase() : 'U', style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 16))),
                                ),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Location bar
                        GestureDetector(
                          onTap: () => setState(() => _showLocationModal = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: kOrange.withOpacity(0.2), width: 1.5)),
                            child: Row(
                              children: [
                                Container(width: 32, height: 32, decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('📍', style: TextStyle(fontSize: 16)))),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('YOUR PICKUP LOCATION', style: TextStyle(fontSize: 10, color: kMuted, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 1),
                                  Text(_currentLocation, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kDark)),
                                ])),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(10)), child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kWhite))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Scrollable body ──
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 80),
                      children: [
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: GestureDetector(
                            onTap: () => _openService(_rideServices[0]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(color: kGray, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 2))]),
                              child: const Row(children: [
                                Text('🔍', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 12),
                                Text('Where do you want to go?', style: TextStyle(fontSize: 14, color: kMuted, fontWeight: FontWeight.w500)),
                              ]),
                            ),
                          ),
                        ),

                        // Ride services
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('🚗 Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kDark)),
                              GestureDetector(onTap: () => setState(() => _seeAll = (title: 'Ride', items: _rideServices)), child: const Text('See all →', style: TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w600))),
                            ]),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9,
                              children: _rideServices.map((s) => ServiceCard(service: s, onTap: () => _openService(s))).toList(),
                            ),
                          ]),
                        ),

                        Container(height: 8, color: kGray),
                        const SizedBox(height: 20),

                        // Delivery services
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('📦 Delivery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kDark)),
                              GestureDetector(onTap: () => setState(() => _seeAll = (title: 'Delivery', items: _deliveryServices)), child: const Text('See all →', style: TextStyle(fontSize: 12, color: kOrange, fontWeight: FontWeight.w600))),
                            ]),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9,
                              children: _deliveryServices.map((s) => ServiceCard(service: s, onTap: () => _openService(s))).toList(),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: kOrangeLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOrange.withOpacity(0.13))),
                              child: const Row(children: [
                                Text('🏍️', style: TextStyle(fontSize: 14)),
                                SizedBox(width: 8),
                                Expanded(child: Text.rich(TextSpan(text: 'All delivery services fulfilled by ', style: TextStyle(fontSize: 11.5, color: kOrange, fontWeight: FontWeight.w600), children: [TextSpan(text: 'bike riders only', style: TextStyle(fontWeight: FontWeight.w800))]))),
                              ]),
                            ),
                          ]),
                        ),

                        Container(height: 8, color: kGray),
                        const SizedBox(height: 20),

                        // Promos
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                          child: Column(children: [
                            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 14), child: Align(alignment: Alignment.centerLeft, child: Text('🎁 Offers for you', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kDark)))),
                            SizedBox(
                              height: 100,
                              child: PageView.builder(
                                controller: _promoPageCtrl,
                                onPageChanged: (i) => setState(() => _promoIdx = i),
                                itemCount: promos.length,
                                itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(right: 12), child: PromoCard(promo: promos[i])),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(promos.length, (i) => GestureDetector(
                              onTap: () { setState(() => _promoIdx = i); _promoPageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
                              child: AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 3), width: _promoIdx == i ? 20 : 6, height: 6, decoration: BoxDecoration(color: _promoIdx == i ? kOrange : const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(99))),
                            ))),
                          ]),
                        ),

                        Container(height: 8, color: kGray),
                        const SizedBox(height: 20),

                        // Recent places
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('🕓 Recent places', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kDark)),
                            const SizedBox(height: 14),
                            ...recentPlaces.map((place) => _RecentPlaceTile(place: place, onTap: () => _openService(_rideServices[0], prefilledDest: '${place.label}, ${place.sub}'))),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
            else if (_activeTab == 'profile')
              SafeArea(
                child: _buildProfileTab(),
              )
            else
              const SafeArea(
                child: Center(child: Text('Coming Soon! 🚀', style: TextStyle(fontSize: 18, color: kMuted))),
              ),

            // Bottom Nav
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: const BoxDecoration(color: kWhite, border: Border(top: BorderSide(color: Color(0xFFF0F0F0))), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))]),
                padding: EdgeInsets.only(top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
                child: Row(
                  children: [
                    for (final tab in [('home', '🏠', 'Home'), ('activity', '📋', 'Activity'), ('wallet', '💰', 'Wallet'), ('profile', '👤', 'Profile')])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = tab.$1),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            AnimatedContainer(duration: const Duration(milliseconds: 200), width: 40, height: 40, decoration: BoxDecoration(color: _activeTab == tab.$1 ? kOrangeLight : Colors.transparent, borderRadius: BorderRadius.circular(14)), child: Center(child: Text(tab.$2, style: const TextStyle(fontSize: 20)))),
                            const SizedBox(height: 4),
                            Text(tab.$3, style: TextStyle(fontSize: 10.5, fontWeight: _activeTab == tab.$1 ? FontWeight.w700 : FontWeight.w500, color: _activeTab == tab.$1 ? kOrange : kMuted)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Modals & Screens (layered)
            if (_showLocationModal)
              Positioned.fill(child: LocationModal(current: _currentLocation, onSelect: (loc) => setState(() { _currentLocation = loc; _showLocationModal = false; }), onClose: () => setState(() => _showLocationModal = false))),

            if (_seeAll != null)
              Positioned.fill(child: SeeAllModal(title: _seeAll!.title, items: _seeAll!.items, onSelect: _openService, onClose: () => setState(() => _seeAll = null))),

            if (_activeScreen != null)
              Positioned.fill(child: WhereToScreen(service: _activeScreen!.service, prefilledDest: _activeScreen!.prefilledDest, onBack: () => setState(() => _activeScreen = null))),
          ],
        ),
      ),
    );
  }
}

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
        decoration: BoxDecoration(color: _hovered ? kOrangeLight : kGray, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))]), child: Center(child: Text(widget.place.icon, style: const TextStyle(fontSize: 18)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.place.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kDark)),
              Text(widget.place.sub, style: const TextStyle(fontSize: 11.5, color: kMuted)),
            ])),
            const Text('›', style: TextStyle(color: kMuted, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
