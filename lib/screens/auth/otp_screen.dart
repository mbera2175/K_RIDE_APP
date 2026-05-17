import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../rider/rider_home_screen.dart';
import '../driver/driver_home_screen.dart';
import 'rider_register_screen.dart';
import 'driver_register_screen.dart';
import 'role_selection_screen.dart';

class OtpScreen extends StatefulWidget {
  final String role; // 'rider' | 'driver'
  const OtpScreen({super.key, required this.role});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _phoneController = TextEditingController();
  final _otpController   = TextEditingController();

  bool _otpSent      = false;
  bool _loading      = false;
  bool _userExists   = false;
  String _devOtp     = '';
  String _error      = '';
  int _resendSeconds = 30;

  // ── Send OTP ───────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _error = ''; });

    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/otp/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'role': widget.role}),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          _otpSent    = true;
          _userExists = data['user_exists'] ?? false;
          _devOtp     = data['dev_otp'] ?? '';
          _resendSeconds = 30;
        });
        _startResendTimer();
      } else {
        setState(() => _error = data['detail'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Check your connection.');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Verify OTP ─────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _error = ''; });

    final phone = _phoneController.text.trim();

    try {
      // ⚠️ FORCE REGISTRATION FLOW FOR TESTING ⚠️
      // Currently, if you use a phone number already in the database, 
      // the app skips registration. We are forcing it here so you can test the UI.
      bool forceRegistrationScreens = false; 

      if (_userExists && !forceRegistrationScreens) {
        // Existing user → login
        final res = await http.post(
          Uri.parse('${AppConstants.baseUrl}/auth/otp/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': phone, 'otp': otp, 'role': widget.role}),
        );
        final data = jsonDecode(res.body);
        if (res.statusCode == 200) {
          _handleLoginSuccess(data);
        } else {
          setState(() => _error = data['detail'] ?? 'Invalid OTP');
        }
      } else {
        // New user (or Forced) → go to registration screen
        if (widget.role == 'rider') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => RiderRegisterScreen(phone: phone, otp: otp),
          ));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => DriverRegisterScreen(phone: phone, otp: otp),
          ));
        }
      }
    } catch (e) {
      setState(() => _error = 'Network error. Try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _handleLoginSuccess(Map data) async {
    // Override role with what the user selected — prevents auto-switching
    // when the same phone number is registered as both Rider and Driver
    final sessionData = Map<String, dynamic>.from(data);
    sessionData['role'] = widget.role;
    await AuthService.saveSession(sessionData);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) =>
        widget.role == 'rider'
          ? const RiderHomeScreen()
          : const DriverHomeScreen()),
      (r) => false);
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      return _resendSeconds > 0;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == 'driver';
    final brandColor = isDriver ? AppColors.driverColor : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Header ─────────────────────────────
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: brandColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDriver ? Icons.drive_eta_rounded : Icons.person_rounded,
                  color: brandColor, size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _otpSent ? 'Enter OTP' : 'Enter your\nPhone Number',
                style: GoogleFonts.sora(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary, height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                  ? 'OTP sent to +91 ${_phoneController.text}'
                  : isDriver
                    ? 'Join as a Driver & start earning'
                    : 'Get ₹50 free on your first ride!',
                style: GoogleFonts.sora(
                  fontSize: 14, color: AppColors.textSecondary,
                ),
              ),

              // ── Dev OTP hint ───────────────────────
              if (_devOtp.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Text('DEV OTP: $_devOtp',
                      style: GoogleFonts.sora(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      )),
                  ]),
                ),
              ],

              const SizedBox(height: 36),

              if (!_otpSent) ...[
                // ── Phone Input ───────────────────────
                Text('Phone Number',
                  style: GoogleFonts.sora(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  )),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: AppColors.divider, width: 1.5)),
                      ),
                      child: Text('+91',
                        style: GoogleFonts.sora(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: GoogleFonts.sora(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: '9XXXXXXXXX',
                          hintStyle: GoogleFonts.sora(color: AppColors.textHint),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          counterText: '',
                        ),
                      ),
                    ),
                  ]),
                ),
              ] else ...[
                // ── OTP Input ─────────────────────────
                Center(
                  child: Pinput(
                    controller: _otpController,
                    length: 6,
                    defaultPinTheme: PinTheme(
                      width: 48, height: 56,
                      textStyle: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider, width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 48, height: 56,
                      textStyle: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: brandColor,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: brandColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onCompleted: (_) => _verifyOtp(),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Resend ────────────────────────────
                Center(
                  child: _resendSeconds > 0
                    ? Text('Resend OTP in $_resendSeconds sec',
                        style: GoogleFonts.sora(
                          fontSize: 13, color: AppColors.textSecondary))
                    : TextButton(
                        onPressed: _sendOtp,
                        child: Text('Resend OTP',
                          style: GoogleFonts.sora(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: brandColor,
                          )),
                      ),
                ),
              ],

              // ── Error ─────────────────────────────
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error,
                      style: GoogleFonts.sora(
                        fontSize: 13, color: AppColors.error))),
                  ]),
                ),
              ],

              const SizedBox(height: 36),

              // ── Button ────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                    : Text(_otpSent ? 'Verify OTP' : 'Send OTP',
                        style: GoogleFonts.sora(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
