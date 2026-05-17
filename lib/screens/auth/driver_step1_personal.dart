import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import 'driver_step2_vehicle.dart';

class DriverStep1Personal extends StatefulWidget {
  final String phone;
  final String otp;
  const DriverStep1Personal({super.key, required this.phone, required this.otp});

  @override
  State<DriverStep1Personal> createState() => _DriverStep1PersonalState();
}

class _DriverStep1PersonalState extends State<DriverStep1Personal> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _referralCtrl = TextEditingController();

  String _gender   = 'male';
  String _language = 'en';

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DriverStep2Vehicle(
        phone    : widget.phone,
        otp      : widget.otp,
        fullName : _nameCtrl.text.trim(),
        email    : _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        gender   : _gender,
        language : _language,
        referral : _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim().toUpperCase(),
      ),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _referralCtrl.dispose();
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
        title: Text('Driver Registration',
          style: GoogleFonts.sora(
            fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _next,
            child: Text('Skip',
              style: GoogleFonts.sora(
                color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
      body: Column(children: [
        _stepBar(1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepTitle('Personal Information', Icons.person_rounded),
                  const SizedBox(height: 4),
                  Text('Step 1 of 4',
                    style: GoogleFonts.sora(
                      fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),

                  // Phone read-only
                  _label('Phone Number'),
                  _readOnly('+91 ${widget.phone}', Icons.phone_rounded),
                  const SizedBox(height: 16),

                  // Full Name
                  _label('Full Name *'),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.sora(fontSize: 14),
                    decoration: _deco('Enter your full name',
                        Icons.person_outline_rounded),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required';
                      if (v.trim().length < 3) return 'Name too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _label('Email (Optional)'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.sora(fontSize: 14),
                    decoration: _deco('your@email.com', Icons.email_outlined),
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (!v.contains('@') || !v.contains('.'))
                          return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Gender
                  _label('Gender'),
                  _dropdown(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'male',   child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other',  child: Text('Prefer not to say')),
                    ],
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const SizedBox(height: 16),

                  // Language
                  _label('Preferred Language'),
                  _dropdown(
                    value: _language,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                      DropdownMenuItem(value: 'bn', child: Text('বাংলা (Bengali)')),
                    ],
                    onChanged: (v) => setState(() => _language = v!),
                  ),
                  const SizedBox(height: 16),

                  // Referral
                  _label('Referral Code (Optional)'),
                  TextFormField(
                    controller: _referralCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.sora(fontSize: 14),
                    decoration: _deco('Enter referral code',
                        Icons.card_giftcard_rounded),
                  ),

                  const SizedBox(height: 32),

                  // Next Button
                  _nextBtn('Continue to Vehicle Details →', _next),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Shared Widgets ─────────────────────────────────────

  Widget _stepBar(int current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(children: [
        Row(children: List.generate(4, (i) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 4,
            decoration: BoxDecoration(
              color: i < current ? AppColors.driverColor : AppColors.divider,
              borderRadius: BorderRadius.circular(2)),
          ),
        ))),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          _stepLabel('Personal', 1, current),
          _stepLabel('Vehicle',  2, current),
          _stepLabel('License',  3, current),
          _stepLabel('Docs',     4, current),
        ]),
      ]),
    );
  }

  Widget _stepLabel(String label, int step, int current) => Text(
    label,
    style: GoogleFonts.sora(
      fontSize: 10,
      fontWeight: step <= current ? FontWeight.w700 : FontWeight.w400,
      color: step <= current ? AppColors.driverColor : AppColors.textHint,
    ));

  Widget _stepTitle(String title, IconData icon) => Row(children: [
    Icon(icon, color: AppColors.driverColor, size: 22),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.sora(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary)),
  ]);

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: GoogleFonts.sora(
      fontSize: 13, fontWeight: FontWeight.w500,
      color: AppColors.textPrimary)));

  Widget _readOnly(String v, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border.all(color: AppColors.divider, width: 1.5),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: AppColors.textSecondary, size: 18),
      const SizedBox(width: 10),
      Text(v, style: GoogleFonts.sora(
        fontSize: 14, color: AppColors.textSecondary)),
    ]));

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.divider, width: 1.5),
      borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value, isExpanded: true,
        style: GoogleFonts.sora(
          fontSize: 14, color: AppColors.textPrimary),
        items: items, onChanged: onChanged)));

  Widget _nextBtn(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.driverColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        elevation: 0),
      child: Text(label, style: GoogleFonts.sora(
        fontSize: 15, fontWeight: FontWeight.w600))));
}
