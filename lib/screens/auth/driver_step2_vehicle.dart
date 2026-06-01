import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'driver_step4_documents.dart';

// ── Emoji vehicle icon widget ─────────────────────────────────
class _VehicleEmoji extends StatelessWidget {
  final String emoji;
  final double size;
  const _VehicleEmoji({required this.emoji, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Text(
      emoji,
      style: TextStyle(
        fontSize: size,
        fontFamily: 'Roboto',
        fontFamilyFallback: const ['Noto Color Emoji', 'Apple Color Emoji', 'Segoe UI Emoji'],
      ),
    );
  }
}

class DriverStep2Vehicle extends StatefulWidget {
  final String  phone;
  final String  otp;
  final String  fullName;
  final String? email;
  final String  gender;
  final String  language;
  final String? referral;

  const DriverStep2Vehicle({
    super.key,
    required this.phone,
    required this.otp,
    required this.fullName,
    this.email,
    required this.gender,
    required this.language,
    this.referral,
  });

  @override
  State<DriverStep2Vehicle> createState() => _DriverStep2VehicleState();
}

class _DriverStep2VehicleState extends State<DriverStep2Vehicle> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _cityCtrl  = TextEditingController();
  final _stateCtrl = TextEditingController();

  String _vehicleType = 'cab_ac';
  bool   _loading     = false;
  String _error       = '';

  // Each entry has 'type', 'emoji', 'label'
  final _vehicles = [
    {'type': 'ac_cab',     'emoji': '🚖', 'label': 'AC Cab'},
    {'type': 'non_ac_cab', 'emoji': '🚕', 'label': 'Non-AC Cab'},
    {'type': 'bike',       'emoji': '🏍️', 'label': 'Bike'},
    {'type': 'auto',       'emoji': '🛺', 'label': 'Auto'},
    {'type': 'toto',       'emoji': '🛵', 'label': 'Toto'},
    {'type': 'ambulance',  'emoji': '🚑', 'label': 'Ambulance'},
  ];

  final _fuelTypes = [
    {'type': 'petrol',  'label': 'Petrol'},
    {'type': 'diesel',  'label': 'Diesel'},
    {'type': 'gas',     'label': 'Gas/CNG'},
    {'type': 'ev',      'label': 'Electric (EV)'},
    {'type': 'hybrid',  'label': 'Hybrid'},
  ];

  String _fuelType = 'petrol';

  // ── Validate + submit to backend ──────────────────────
  Future<void> _submitAndNext() async {
    if (_brandCtrl.text.trim().isEmpty ||
        _modelCtrl.text.trim().isEmpty ||
        _colorCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill vehicle brand, model and color');
      return;
    }
    if (_cityCtrl.text.trim().isEmpty) {
      setState(() => _error = 'City is required');
      return;
    }
    setState(() { _loading = true; _error = ''; });

    final res = await ApiService.registerDriver({
      'phone'        : widget.phone,
      'otp'          : widget.otp,
      'full_name'    : widget.fullName,
      'email'        : widget.email,
      'gender'       : widget.gender,
      'language'     : widget.language,
      'referral_code': widget.referral,
      'vehicle_type' : _vehicleType,
      'fuel_type'    : _fuelType,
      'service_type' : 'ride',
      'brand'        : _brandCtrl.text.trim(),
      'model'        : _modelCtrl.text.trim(),
      'color'        : _colorCtrl.text.trim(),
      'city'         : _cityCtrl.text.trim(),
      'state'        : _stateCtrl.text.trim().isEmpty
                          ? 'West Bengal' : _stateCtrl.text.trim(),
    });

    setState(() => _loading = false);

    if (res['success']) {
      await AuthService.saveSession(res['data']);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DriverStep4Documents(
          driverId: res['data']['driver_id'] ?? 0,
        )));
    } else {
      setState(() => _error = res['error'] ?? 'Registration failed');
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _colorCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: _loading ? null : () => Navigator.pop(context)),
        title: Text('Vehicle Details',
          style: GoogleFonts.sora(
            fontSize: 17, fontWeight: FontWeight.w600)),
        // No skip — this page is not skippable
      ),
      body: Column(children: [
        _stepBar(2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepTitle('Vehicle Details', Icons.directions_car_rounded),
                const SizedBox(height: 4),
                Text('Step 2 of 3',
                  style: GoogleFonts.sora(
                    fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 24),

                // ── Vehicle Type ──────────────────────
                _label('Vehicle Type *'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                  // FIX: use ?? '' to safely convert String? → String
                  children: _vehicles.map((v) =>
                    _vehicleCard(v['type'] ?? '', v['emoji'] ?? '', v['label'] ?? '')).toList(),
                ),

                const SizedBox(height: 16),

                // ── Brand ─────────────────────────────
                _label('Vehicle Brand *'),
                _textField(_brandCtrl, 'e.g. Honda, Bajaj, Maruti',
                    Icons.branding_watermark_outlined,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── Model ─────────────────────────────
                _label('Vehicle Model *'),
                _textField(_modelCtrl, 'e.g. Activa, Swift, Pulsar',
                    Icons.directions_car_outlined,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── Color ─────────────────────────────
                _label('Vehicle Color *'),
                _textField(_colorCtrl, 'e.g. White, Black, Silver',
                    Icons.color_lens_outlined,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── City ──────────────────────────────
                _label('City *'),
                _textField(_cityCtrl, 'e.g. Kolkata, Delhi, Mumbai',
                    Icons.location_city_rounded,
                    capitalization: TextCapitalization.words),

                const SizedBox(height: 16),

                // ── State ─────────────────────────────
                _label('State (Optional)'),
                _textField(_stateCtrl, 'e.g. West Bengal, Delhi',
                    Icons.map_outlined,
                    capitalization: TextCapitalization.words),

                // ── Info banner ───────────────────────
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withOpacity(0.3))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    const Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Your account will be reviewed within 24 hours '
                      'after document upload. You\'ll be notified once approved.',
                      style: GoogleFonts.sora(
                        fontSize: 12, color: AppColors.info,
                        height: 1.5))),
                  ]),
                ),

                // ── Error ─────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _errorBox(_error),
                ],

                const SizedBox(height: 32),

                // ── Submit button ──────────────────────
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitAndNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.driverColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                    child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                      : Text('Save & Upload Documents →',
                          style: GoogleFonts.sora(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Small widgets ──────────────────────────────────────

  Widget _vehicleCard(String type, String emoji, String label) {
    final selected = _vehicleType == type;
    return GestureDetector(
      onTap: _loading ? null : () {
        setState(() => _vehicleType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.driverColor.withOpacity(0.08)
              : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.driverColor : AppColors.divider,
            width: selected ? 2 : 1.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? [
            BoxShadow(
              color: AppColors.driverColor.withOpacity(0.15),
              blurRadius: 10, offset: const Offset(0, 4))
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _VehicleEmoji(emoji: emoji, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 10, fontWeight: FontWeight.w600,
                color: selected ? AppColors.driverColor : AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBar(int current) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Column(children: [
      Row(children: List.generate(3, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 4,
          decoration: BoxDecoration(
            color: i < current ? AppColors.driverColor : AppColors.divider,
            borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        _stepLabel('Personal', 1, current),
        _stepLabel('Vehicle',  2, current),
        _stepLabel('Docs',     3, current),
      ]),
    ]));

  Widget _stepLabel(String label, int step, int current) => Text(label,
    style: GoogleFonts.sora(
      fontSize: 10,
      fontWeight: step <= current ? FontWeight.w700 : FontWeight.w400,
      color: step <= current ? AppColors.driverColor : AppColors.textHint));

  Widget _stepTitle(String title, IconData icon) => Row(children: [
    Icon(icon, color: AppColors.driverColor, size: 22),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.sora(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary))]);

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: GoogleFonts.sora(
      fontSize: 13, fontWeight: FontWeight.w500,
      color: AppColors.textPrimary)));

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType type = TextInputType.text,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    textCapitalization: capitalization,
    enabled: !_loading,
    style: GoogleFonts.sora(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(color: AppColors.textHint, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.driverColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: GoogleFonts.sora(
        fontSize: 13, color: AppColors.error))),
    ]));
}
