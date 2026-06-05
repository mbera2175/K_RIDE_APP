import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'driver_step4_documents.dart';

class DriverStep3License extends StatefulWidget {
  final String  phone;
  final String  otp;
  final String  fullName;
  final String? email;
  final String  gender;
  final String  language;
  final String? referral;
  final String  vehicleType;
  final String  plateNumber;
  final String  brand;
  final String  model;
  final String  color;
  final int     regYear;
  final int     expireYear;

  const DriverStep3License({
    super.key,
    required this.phone,
    required this.otp,
    required this.fullName,
    this.email,
    required this.gender,
    required this.language,
    this.referral,
    required this.vehicleType,
    required this.plateNumber,
    required this.brand,
    required this.model,
    required this.color,
    required this.regYear,
    required this.expireYear,
  });

  @override
  State<DriverStep3License> createState() => _DriverStep3LicenseState();
}

class _DriverStep3LicenseState extends State<DriverStep3License> {
  final _licenseCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();

  DateTime? _licenseExpiry;
  bool      _loading = false;
  String    _error   = '';

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context   : context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate : DateTime.now(),
      lastDate  : DateTime(2045),
      builder   : (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.driverColor)),
        child: child!));
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  // ── Submit registration to backend ─────────────────────
  Future<void> _submitAndNext() async {
    if (_licenseCtrl.text.trim().isEmpty) {
      setState(() => _error = 'License number is required'); return;
    }
    if (_licenseExpiry == null) {
      setState(() => _error = 'License expiry date is required'); return;
    }
    if (_cityCtrl.text.trim().isEmpty) {
      setState(() => _error = 'City is required'); return;
    }

    setState(() { _loading = true; _error = ''; });

    final expiry =
      '${_licenseExpiry!.year}-'
      '${_licenseExpiry!.month.toString().padLeft(2, '0')}-'
      '${_licenseExpiry!.day.toString().padLeft(2, '0')}';

    final res = await ApiService.registerDriver({
      'phone'          : widget.phone,
      'otp'            : widget.otp,
      'full_name'      : widget.fullName,
      'email'          : widget.email,
      'gender'         : widget.gender,
      'language'       : widget.language,
      'referral_code'  : widget.referral,
      'vehicle_type'   : widget.vehicleType,
      'plate_number'   : widget.plateNumber,
      'brand'          : widget.brand,
      'model'          : widget.model,
      'color'          : widget.color,
      'year'           : widget.regYear,
      'license_number' : _licenseCtrl.text.trim().toUpperCase(),
      'license_expiry' : expiry,
      'city'           : _cityCtrl.text.trim(),
      'state'          : _stateCtrl.text.trim().isEmpty
                            ? 'Delhi' : _stateCtrl.text.trim(),
    });

    setState(() => _loading = false);

    if (res['success']) {
      await AuthService.saveSession(res['data']);
      if (!mounted) return;
      // Go to document upload step
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DriverStep4Documents(
          driverId: res['data']['driver_id'] ?? 0,
        )));
    } else {
      setState(() => _error = res['error']);
    }
  }

  void _skip() {
    // Skip license — try to submit with what we have
    _submitAndNext();
  }

  @override
  void dispose() {
    _licenseCtrl.dispose();
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
          onPressed: () => Navigator.pop(context)),
        title: Text('License Details',
          style: GoogleFonts.sora(
            fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _skip,
            child: Text('Skip',
              style: GoogleFonts.sora(
                color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
      body: Column(children: [
        _stepBar(3),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stepTitle('License Details', Icons.badge_rounded),
                const SizedBox(height: 4),
                Text('Step 3 of 4',
                  style: GoogleFonts.sora(
                    fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 24),

                // ── License Number ────────────────────
                _label('Driving License Number *'),
                _textField(
                  _licenseCtrl,
                  'e.g. WB0120110012345',
                  Icons.credit_card_rounded,
                  capitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),

                // ── License Expiry ────────────────────
                _label('License Expiry Date *'),
                GestureDetector(
                  onTap: _pickExpiry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _licenseExpiry == null
                            ? AppColors.divider
                            : AppColors.driverColor,
                        width: 1.5),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                        color: _licenseExpiry == null
                            ? AppColors.textSecondary
                            : AppColors.driverColor,
                        size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _licenseExpiry == null
                          ? 'Select expiry date'
                          : '${_licenseExpiry!.day}/'
                            '${_licenseExpiry!.month}/'
                            '${_licenseExpiry!.year}',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          color: _licenseExpiry == null
                              ? AppColors.textHint
                              : AppColors.textPrimary)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.textSecondary),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // ── City ──────────────────────────────
                _label('City *'),
                _textField(
                  _cityCtrl,
                  'e.g. Kolkata, Delhi, Mumbai',
                  Icons.location_city_rounded,
                  capitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // ── State ─────────────────────────────
                _label('State (Optional)'),
                _textField(
                  _stateCtrl,
                  'e.g. West Bengal, Delhi',
                  Icons.map_outlined,
                  capitalization: TextCapitalization.words,
                ),

                // ── Info box ──────────────────────────
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

                // ── Submit Button ─────────────────────
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),

                Center(child: TextButton(
                  onPressed: _loading ? null : _skip,
                  child: Text('Skip for now',
                    style: GoogleFonts.sora(
                      color: AppColors.textSecondary,
                      fontSize: 13)),
                )),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Shared Widgets ─────────────────────────────────────

  Widget _stepBar(int current) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Column(children: [
      Row(children: List.generate(4, (i) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 4,
          decoration: BoxDecoration(
            color: i < current
                ? AppColors.driverColor : AppColors.divider,
            borderRadius: BorderRadius.circular(2)))))),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        _stepLabel('Personal', 1, current),
        _stepLabel('Vehicle',  2, current),
        _stepLabel('License',  3, current),
        _stepLabel('Docs',     4, current),
      ]),
    ]));

  Widget _stepLabel(String label, int step, int current) => Text(label,
    style: GoogleFonts.sora(
      fontSize: 10,
      fontWeight: step <= current
          ? FontWeight.w700 : FontWeight.w400,
      color: step <= current
          ? AppColors.driverColor : AppColors.textHint));

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
    int? maxLen,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    textCapitalization: capitalization,
    maxLength: maxLen,
    style: GoogleFonts.sora(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(
        color: AppColors.textHint, fontSize: 14),
      prefixIcon: Icon(icon,
        color: AppColors.textSecondary, size: 20),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.divider, width: 1.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.divider, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.driverColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 14)));

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.error_outline,
        color: AppColors.error, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: GoogleFonts.sora(
        fontSize: 13, color: AppColors.error))),
    ]));
}
