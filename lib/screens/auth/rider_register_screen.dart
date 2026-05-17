import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../rider/rider_home_screen.dart';

class RiderRegisterScreen extends StatefulWidget {
  final String phone;
  final String otp;
  const RiderRegisterScreen({super.key, required this.phone, required this.otp});

  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _referralCtrl = TextEditingController();

  String _gender   = 'male';
  String _language = 'en';
  bool   _loading  = false;
  String _error    = '';

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = ''; });

    final res = await ApiService.registerRider({
      'phone'        : widget.phone,
      'otp'          : widget.otp,
      'full_name'    : _nameCtrl.text.trim(),
      'email'        : _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'gender'       : _gender,
      'language'     : _language,
      'referral_code': _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim().toUpperCase(),
    });

    setState(() => _loading = false);

    if (res['success']) {
      await AuthService.saveSession(res['data']);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
        (r) => false);
    } else {
      setState(() => _error = res['error']);
    }
  }

  void _skip() {
    // Navigate to home without completing registration
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => const RiderHomeScreen()),
      (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text('Create Account',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text('Skip',
              style: GoogleFonts.sora(
                color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Bonus Banner ──────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Text('🎉', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹50 Signup Bonus!',
                          style: GoogleFonts.sora(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.success)),
                        Text('Added to wallet on registration',
                          style: GoogleFonts.sora(
                            fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    )),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Phone (read-only) ─────────────────
                _label('Phone Number'),
                _readOnly('+91 ${widget.phone}', Icons.phone_rounded),

                const SizedBox(height: 16),

                // ── Full Name ─────────────────────────
                _label('Full Name *'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.sora(fontSize: 14),
                  decoration: _deco('Enter your full name', Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 3) return 'Name too short';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Email ─────────────────────────────
                _label('Email (Optional)'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.sora(fontSize: 14),
                  decoration: _deco('your@email.com', Icons.email_outlined),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      if (!v.contains('@') || !v.contains('.')) return 'Invalid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Gender ────────────────────────────
                _label('Gender'),
                _dropdownField(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'male',   child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other',  child: Text('Prefer not to say')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                ),

                const SizedBox(height: 16),

                // ── Language ──────────────────────────
                _label('Preferred Language'),
                _dropdownField(
                  value: _language,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
                    DropdownMenuItem(value: 'bn', child: Text('বাংলা (Bengali)')),
                  ],
                  onChanged: (v) => setState(() => _language = v!),
                ),

                const SizedBox(height: 16),

                // ── Referral ──────────────────────────
                _label('Referral Code (Optional)'),
                TextFormField(
                  controller: _referralCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.sora(fontSize: 14),
                  decoration: _deco('Enter referral code', Icons.card_giftcard_rounded),
                ),

                // ── Error ─────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _errorBox(_error),
                ],

                const SizedBox(height: 32),

                // ── Button ────────────────────────────
                _submitBtn('Create Account 🎉', AppColors.primary, _loading, _register),

                const SizedBox(height: 12),

                Center(child: TextButton(
                  onPressed: _skip,
                  child: Text('Skip for now',
                    style: GoogleFonts.sora(
                      color: AppColors.textSecondary, fontSize: 13)),
                )),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));

  Widget _dropdownField<T>({
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
        style: GoogleFonts.sora(fontSize: 14, color: AppColors.textPrimary),
        items: items, onChanged: onChanged)));

  Widget _errorBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
        style: GoogleFonts.sora(fontSize: 13, color: AppColors.error))),
    ]));

  Widget _submitBtn(String label, Color color, bool loading, VoidCallback onTap) =>
    SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0),
        child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(label, style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w600))));
}
