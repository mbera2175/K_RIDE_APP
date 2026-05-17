import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';
import '../../services/api_service.dart';
import '../driver/driver_home_screen.dart';

class DriverStep4Documents extends StatefulWidget {
  final int driverId;
  const DriverStep4Documents({super.key, required this.driverId});

  @override
  State<DriverStep4Documents> createState() => _DriverStep4DocumentsState();
}

class _DriverStep4DocumentsState extends State<DriverStep4Documents> {
  final ImagePicker _picker = ImagePicker();

  // ── Profile picture ────────────────────────────────────
  File? _profilePic;

  // ── RC Details ─────────────────────────────────────────
  final _rcNumberCtrl = TextEditingController();
  int   _rcRegYear    = DateTime.now().year;
  int   _rcExpireYear = DateTime.now().year + 1;
  File? _rcFront;
  File? _rcBack;

  // ── DL Details ─────────────────────────────────────────
  final _dlNumberCtrl = TextEditingController();
  int   _dlExpireYear = DateTime.now().year + 1;
  File? _dlFront;
  File? _dlBack;

  // ── Aadhaar Details ────────────────────────────────────
  final _aadhaarCtrl = TextEditingController();
  File? _aadhaarFront;
  File? _aadhaarBack;

  // ── Insurance & Permit ─────────────────────────────────
  File? _insurance;
  File? _permit;

  // ── Upload state ───────────────────────────────────────
  bool   _uploading      = false;
  String _uploadingLabel = '';
  int    _uploadedCount  = 0;
  int    _totalSlots     = 0;
  String _error          = '';

  // ── Pick image helper ──────────────────────────────────
  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Choose Image Source',
              style: GoogleFonts.sora(
                fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _sourceBtn(
                Icons.camera_alt_rounded, 'Camera', AppColors.primary,
                () => Navigator.pop(context, ImageSource.camera))),
              const SizedBox(width: 12),
              Expanded(child: _sourceBtn(
                Icons.photo_library_rounded, 'Gallery', AppColors.driverColor,
                () => Navigator.pop(context, ImageSource.gallery))),
            ]),
          ]),
        ),
      ),
    );
    if (source == null) return null;
    final picked = await _picker.pickImage(
      source: source, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return null;
    return File(picked.path);
  }

  Widget _sourceBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.sora(
            fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );

  // ── Upload single file ─────────────────────────────────
  Future<bool> _uploadFile(File file, String docType) async {
    setState(() => _uploadingLabel = _labelFor(docType));
    final result = await ApiService.uploadDocument(
      driverId: widget.driverId,
      docType:  docType,
      file:     file,
    );
    if (result['success'] == true) {
      setState(() => _uploadedCount++);
      return true;
    }
    return false;
  }

  // ── Save text details to backend ───────────────────────
  Future<void> _saveDocDetails() async {
    await ApiService.saveDocumentDetails(
      driverId:         widget.driverId,
      rcNumber:         _rcNumberCtrl.text.trim().isEmpty ? null : _rcNumberCtrl.text.trim().toUpperCase(),
      rcRegYear:        _rcRegYear,
      rcExpireYear:     _rcExpireYear,
      dlNumber:         _dlNumberCtrl.text.trim().isEmpty ? null : _dlNumberCtrl.text.trim().toUpperCase(),
      dlExpireYear:     _dlExpireYear,
      aadhaarNumber:    _aadhaarCtrl.text.trim().isEmpty ? null : _aadhaarCtrl.text.trim(),
    );
  }

  // ── Validate required sections ─────────────────────────
  String? _validate() {
    if (_profilePic == null) return 'Profile picture is required';
    if (_rcFront == null || _rcBack == null) return 'RC front and back photos are required';
    if (_dlFront == null || _dlBack == null) return 'DL front and back photos are required';
    if (_aadhaarFront == null || _aadhaarBack == null) return 'Aadhaar front and back photos are required';
    if (_insurance == null) return 'Insurance certificate is required';
    return null;
  }

  // ── Submit all docs ────────────────────────────────────
  Future<void> _submitDocs() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _error = ''; _uploading = true; _uploadedCount = 0; });

    // Count total slots
    final slots = <Map<String, dynamic>>[
      {'file': _profilePic!,  'type': 'profile_pic'},
      {'file': _rcFront!,     'type': 'rc_front'},
      {'file': _rcBack!,      'type': 'rc_back'},
      {'file': _dlFront!,     'type': 'dl_front'},
      {'file': _dlBack!,      'type': 'dl_back'},
      {'file': _aadhaarFront!,'type': 'aadhaar_front'},
      {'file': _aadhaarBack!, 'type': 'aadhaar_back'},
      {'file': _insurance!,   'type': 'insurance'},
      if (_permit != null) {'file': _permit!, 'type': 'permit'},
    ];
    setState(() => _totalSlots = slots.length);

    // Save text details first
    await _saveDocDetails();

    // Upload images
    final List<String> failed = [];
    for (final slot in slots) {
      final ok = await _uploadFile(slot['file'] as File, slot['type'] as String);
      if (!ok) failed.add(slot['type'] as String);
    }

    setState(() => _uploading = false);

    if (failed.isNotEmpty) {
      _showPartialErrorDialog(failed);
    } else {
      _showSuccessDialog();
    }
  }

  // ── Skip (go to home, upload later from My Documents) ──
  void _skip() {
    _showSuccessDialog(skipped: true);
  }

  String _labelFor(String t) {
    const m = {
      'profile_pic':   'Profile Picture',
      'rc_front':      'RC Front',
      'rc_back':       'RC Back',
      'dl_front':      'DL Front',
      'dl_back':       'DL Back',
      'aadhaar_front': 'Aadhaar Front',
      'aadhaar_back':  'Aadhaar Back',
      'insurance':     'Insurance',
      'permit':        'Permit',
    };
    return m[t] ?? t;
  }

  void _showSuccessDialog({bool skipped = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 48)),
          const SizedBox(height: 16),
          Text('Registration Complete! 🎉',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Text(
            skipped
              ? 'Your account is under review.\nUpload your documents later from\nProfile → My Documents.'
              : 'Documents uploaded! ✅\nYour account is under review.\nWe\'ll notify you within 24 hours.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          if (skipped) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Text(
                '📋 Upload documents later from\nProfile → My Documents',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 12, color: AppColors.warning,
                  fontWeight: FontWeight.w500))),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                  (r) => false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.driverColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text('Go to Dashboard',
                style: GoogleFonts.sora(
                  color: Colors.white, fontWeight: FontWeight.w600,
                  fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showPartialErrorDialog(List<String> failed) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Some uploads failed',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('These could not be uploaded:',
            style: GoogleFonts.sora(fontSize: 13)),
          const SizedBox(height: 8),
          ...failed.map((f) => Text('• ${_labelFor(f)}',
            style: GoogleFonts.sora(
              fontSize: 13, color: AppColors.error))),
          const SizedBox(height: 12),
          Text('Retry from Profile → My Documents.',
            style: GoogleFonts.sora(
              fontSize: 12, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
                (r) => false);
            },
            child: Text('Continue',
              style: GoogleFonts.sora(color: AppColors.driverColor))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _submitDocs(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.driverColor),
            child: Text('Retry',
              style: GoogleFonts.sora(color: Colors.white))),
        ],
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: _uploading ? null : () => Navigator.pop(context)),
        title: Text('Upload Documents',
          style: GoogleFonts.sora(
            fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          // Only this page is skippable
          TextButton(
            onPressed: _uploading ? null : _skip,
            child: Text('Skip',
              style: GoogleFonts.sora(
                color: AppColors.textSecondary, fontSize: 14)),
          ),
        ],
      ),
      body: Column(children: [
        _stepBar(3),

        // Upload progress
        if (_uploading)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Text('Uploading $_uploadingLabel...',
                  style: GoogleFonts.sora(
                    fontSize: 12, color: AppColors.driverColor,
                    fontWeight: FontWeight.w600)),
                Text('$_uploadedCount / $_totalSlots',
                  style: GoogleFonts.sora(
                    fontSize: 12, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _totalSlots > 0 ? _uploadedCount / _totalSlots : 0,
                backgroundColor: AppColors.divider,
                color: AppColors.driverColor, minHeight: 6),
            ]),
          ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _sectionHeader('Step 3 of 3 — Documents', Icons.folder_rounded),
                const SizedBox(height: 4),
                Text('Upload your documents clearly. Permit is optional.',
                  style: GoogleFonts.sora(
                    fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 20),

                // ══════════════════════════════════════
                // 1. PROFILE PICTURE
                // ══════════════════════════════════════
                _sectionCard(
                  icon: Icons.person_rounded,
                  color: AppColors.driverColor,
                  title: 'Profile Picture',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Rules banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withOpacity(0.4))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Photo rules: No helmet • No sunglasses • No cap\n'
                          'Clear face photo in good lighting',
                          style: GoogleFonts.sora(
                            fontSize: 11, color: AppColors.warning,
                            fontWeight: FontWeight.w500, height: 1.4))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _fullWidthUploadSlot(
                      file: _profilePic,
                      label: 'Upload Profile Photo',
                      color: AppColors.driverColor,
                      height: 160,
                      onPick: () async {
                        final f = await _pickImage();
                        if (f != null) setState(() => _profilePic = f);
                      },
                      onRemove: () => setState(() => _profilePic = null),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ══════════════════════════════════════
                // 2. RC DETAILS
                // ══════════════════════════════════════
                _sectionCard(
                  icon: Icons.directions_car_rounded,
                  color: AppColors.primary,
                  title: 'RC (Registration Certificate)',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _label('RC Number'),
                    _textField(_rcNumberCtrl, 'e.g. WB01AB1234',
                      Icons.pin_outlined,
                      capitalization: TextCapitalization.characters),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _label('Registration Year'),
                        _yearDropdown(
                          value: _rcRegYear,
                          from: DateTime.now().year - 20,
                          to: DateTime.now().year,
                          onChanged: (v) => setState(() => _rcRegYear = v!),
                          color: AppColors.primary),
                      ])),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _label('Expire Year'),
                        _yearDropdown(
                          value: _rcExpireYear,
                          from: DateTime.now().year,
                          to: DateTime.now().year + 15,
                          onChanged: (v) => setState(() => _rcExpireYear = v!),
                          color: AppColors.primary),
                      ])),
                    ]),
                    const SizedBox(height: 12),
                    _label('Front & Back Photos'),
                    Row(children: [
                      Expanded(child: _uploadSlot(
                        file: _rcFront, label: 'Front Side',
                        color: AppColors.primary,
                        onPick: () async {
                          final f = await _pickImage();
                          if (f != null) setState(() => _rcFront = f);
                        },
                        onRemove: () => setState(() => _rcFront = null))),
                      const SizedBox(width: 12),
                      Expanded(child: _uploadSlot(
                        file: _rcBack, label: 'Back Side',
                        color: AppColors.primary,
                        onPick: () async {
                          final f = await _pickImage();
                          if (f != null) setState(() => _rcBack = f);
                        },
                        onRemove: () => setState(() => _rcBack = null))),
                    ]),
                  ]),
                ),

                const SizedBox(height: 16),

                // ══════════════════════════════════════
                // 3. DL DETAILS
                // ══════════════════════════════════════
                _sectionCard(
                  icon: Icons.badge_rounded,
                  color: AppColors.driverColor,
                  title: 'Driving Licence (DL)',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _label('DL Number'),
                    _textField(_dlNumberCtrl, 'e.g. WB0120110012345',
                      Icons.credit_card_rounded,
                      capitalization: TextCapitalization.characters),
                    const SizedBox(height: 12),
                    _label('Expire Year'),
                    _yearDropdown(
                      value: _dlExpireYear,
                      from: DateTime.now().year,
                      to: DateTime.now().year + 20,
                      onChanged: (v) => setState(() => _dlExpireYear = v!),
                      color: AppColors.driverColor),
                    const SizedBox(height: 12),
                    _label('Front & Back Photos'),
                    Row(children: [
                      Expanded(child: _uploadSlot(
                        file: _dlFront, label: 'Front Side',
                        color: AppColors.driverColor,
                        onPick: () async {
                          final f = await _pickImage();
                          if (f != null) setState(() => _dlFront = f);
                        },
                        onRemove: () => setState(() => _dlFront = null))),
                      const SizedBox(width: 12),
                      Expanded(child: _uploadSlot(
                        file: _dlBack, label: 'Back Side',
                        color: AppColors.driverColor,
                        onPick: () async {
                          final f = await _pickImage();
                          if (f != null) setState(() => _dlBack = f);
                        },
                        onRemove: () => setState(() => _dlBack = null))),
                    ]),
                  ]),
                ),

                const SizedBox(height: 16),

                // ══════════════════════════════════════
                // 4. AADHAAR
                // ══════════════════════════════════════
                _sectionCard(
                  icon: Icons.fingerprint_rounded,
                  color: AppColors.success,
                  title: 'Aadhaar Card',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _label('Aadhaar Number'),
                    _textField(_aadhaarCtrl, 'e.g. 1234 5678 9012',
                      Icons.numbers_rounded,
                      type: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ]),
                    const SizedBox(height: 12),
                    _label('Front & Back Photos'),
                    Row(children: [
                      Expanded(child: _uploadSlot(
                        file: _aadhaarFront, label: 'Front Side',
                        color: AppColors.success,
                        onPick: () async {
                          final f = await _pickImage();
                          if (f != null) setState(() => _aadhaarFront = f);
                        },
                        onRemove: () => setState(() => _aadhaarFront = null))),
                      const SizedBox(width: 12),
                      Expanded(child: _uploadSlot(
                        file: _aadhaarBack, label: 'Back Side',
                        color: AppColors.success,
                        onPick: () async {
                          final f = await _pickImage();
                          if (f != null) setState(() => _aadhaarBack = f);
                        },
                        onRemove: () => setState(() => _aadhaarBack = null))),
                    ]),
                  ]),
                ),

                const SizedBox(height: 16),

                // ══════════════════════════════════════
                // 5. INSURANCE
                // ══════════════════════════════════════
                _sectionCard(
                  icon: Icons.security_rounded,
                  color: AppColors.warning,
                  title: 'Insurance Certificate',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: _fullWidthUploadSlot(
                    file: _insurance,
                    label: 'Upload Insurance Certificate',
                    color: AppColors.warning,
                    height: 100,
                    onPick: () async {
                      final f = await _pickImage();
                      if (f != null) setState(() => _insurance = f);
                    },
                    onRemove: () => setState(() => _insurance = null),
                  ),
                ),

                const SizedBox(height: 16),

                // ══════════════════════════════════════
                // 6. VEHICLE PERMIT (optional)
                // ══════════════════════════════════════
                _sectionCard(
                  icon: Icons.article_rounded,
                  color: AppColors.info,
                  title: 'Vehicle Permit',
                  badge: 'Optional',
                  badgeColor: AppColors.textSecondary,
                  child: _fullWidthUploadSlot(
                    file: _permit,
                    label: 'Upload Permit (if applicable)',
                    color: AppColors.info,
                    height: 100,
                    onPick: () async {
                      final f = await _pickImage();
                      if (f != null) setState(() => _permit = f);
                    },
                    onRemove: () => setState(() => _permit = null),
                  ),
                ),

                // ── Error ──────────────────────────────
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _errorBox(_error),
                ],

                const SizedBox(height: 32),

                // ── Submit button ──────────────────────
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: _uploading ? null : _submitDocs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.driverColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                    child: _uploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5)),
                          const SizedBox(width: 12),
                          Text('Uploading $_uploadedCount / $_totalSlots...',
                            style: GoogleFonts.sora(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                        ])
                      : Text('Submit Documents ✅',
                          style: GoogleFonts.sora(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),

                Center(child: TextButton(
                  onPressed: _uploading ? null : _skip,
                  child: Text('Skip — upload later from Profile → My Documents',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      color: AppColors.textSecondary, fontSize: 13)),
                )),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Section header ─────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) => Row(children: [
    Icon(icon, color: AppColors.driverColor, size: 22),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.sora(
      fontSize: 18, fontWeight: FontWeight.w700,
      color: AppColors.textPrimary)),
  ]);

  // ── Section card wrapper ───────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String badge,
    required Color badgeColor,
    required Widget child,
  }) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider, width: 1.5),
      boxShadow: [BoxShadow(
        color: AppColors.shadow,
        blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      // Card header
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: GoogleFonts.sora(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: GoogleFonts.sora(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: badgeColor))),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    ]),
  );

  // ── Two-column upload slot ─────────────────────────────
  Widget _uploadSlot({
    required File? file,
    required String label,
    required Color color,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) => GestureDetector(
    onTap: (_uploading || file != null) ? null : onPick,
    child: Container(
      height: 100,
      decoration: BoxDecoration(
        color: file != null ? Colors.transparent : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file != null
              ? AppColors.success.withOpacity(0.4)
              : color.withOpacity(0.3),
          width: 1.5)),
      child: file != null
        ? Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.file(file,
                width: double.infinity, height: double.infinity,
                fit: BoxFit.cover)),
            Positioned(top: 4, right: 4,
              child: Row(children: [
                GestureDetector(
                  onTap: onPick,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 14))),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 14))),
              ])),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(11))),
                child: Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 10, color: Colors.white,
                    fontWeight: FontWeight.w600)))),
          ])
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(Icons.cloud_upload_rounded,
              color: color.withOpacity(0.6), size: 26),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8))),
            Text('Tap to upload',
              style: GoogleFonts.sora(
                fontSize: 10, color: AppColors.textHint)),
          ]),
    ),
  );

  // ── Full-width upload slot ─────────────────────────────
  Widget _fullWidthUploadSlot({
    required File? file,
    required String label,
    required Color color,
    required double height,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) => GestureDetector(
    onTap: (_uploading || file != null) ? null : onPick,
    child: Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: file != null ? Colors.transparent : color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: file != null
              ? AppColors.success.withOpacity(0.4)
              : color.withOpacity(0.3),
          width: 1.5)),
      child: file != null
        ? Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.file(file,
                width: double.infinity, height: double.infinity,
                fit: BoxFit.cover)),
            Positioned(top: 4, right: 4,
              child: Row(children: [
                GestureDetector(
                  onTap: onPick,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16))),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 16))),
              ])),
          ])
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(Icons.cloud_upload_rounded,
              color: color.withOpacity(0.6), size: 30),
            const SizedBox(height: 6),
            Text(label,
              style: GoogleFonts.sora(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8))),
            const SizedBox(height: 2),
            Text('Tap to upload',
              style: GoogleFonts.sora(
                fontSize: 11, color: AppColors.textHint)),
          ]),
    ),
  );

  // ── Step bar ───────────────────────────────────────────
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

  Widget _stepLabel(String label, int step, int current) =>
    Text(label, style: GoogleFonts.sora(
      fontSize: 10,
      fontWeight: step <= current ? FontWeight.w700 : FontWeight.w400,
      color: step <= current ? AppColors.driverColor : AppColors.textHint));

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.sora(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: AppColors.textPrimary)));

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    textCapitalization: capitalization,
    inputFormatters: inputFormatters,
    enabled: !_uploading,
    style: GoogleFonts.sora(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(color: AppColors.textHint, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.driverColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));

  Widget _yearDropdown({
    required int value,
    required int from,
    required int to,
    required void Function(int?) onChanged,
    required Color color,
  }) {
    final years = List.generate(to - from + 1, (i) => from + i).reversed.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider, width: 1.5),
        borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value, isExpanded: true,
          style: GoogleFonts.sora(
            fontSize: 13, color: AppColors.textPrimary),
          items: years.map((y) => DropdownMenuItem(
            value: y, child: Text('$y'))).toList(),
          onChanged: _uploading ? null : onChanged)));
  }

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

  @override
  void dispose() {
    _rcNumberCtrl.dispose();
    _dlNumberCtrl.dispose();
    _aadhaarCtrl.dispose();
    super.dispose();
  }
}
