import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';

class MyDocumentsScreen extends StatefulWidget {
  final int driverId;
  const MyDocumentsScreen({super.key, required this.driverId});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  final ImagePicker _picker = ImagePicker();

  // ── Existing uploaded URLs from backend ────────────────
  Map<String, String> _uploadedUrls = {};

  // ── Text detail controllers ────────────────────────────
  final _rcNumberCtrl  = TextEditingController();
  final _dlNumberCtrl  = TextEditingController();
  final _aadhaarCtrl   = TextEditingController();
  int _rcRegYear       = DateTime.now().year;
  int _rcExpireYear    = DateTime.now().year + 1;
  int _dlExpireYear    = DateTime.now().year + 1;

  // ── New files selected locally ─────────────────────────
  final Map<String, File?> _newFiles = {
    'profile_pic'   : null,
    'rc_front'      : null,
    'rc_back'       : null,
    'dl_front'      : null,
    'dl_back'       : null,
    'aadhaar_front' : null,
    'aadhaar_back'  : null,
    'insurance'     : null,
    'permit'        : null,
  };

  bool   _loading        = false;
  bool   _saving         = false;
  String _uploadingLabel = '';
  String _error          = '';
  String _success        = '';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  // ── Load existing docs & details from backend ──────────
  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final res = await ApiService.getDocuments(widget.driverId);
    if (res['success']) {
      final data = res['data'] as Map<String, dynamic>;
      final urls = <String, String>{};
      for (final key in _newFiles.keys) {
        final v = data[key] ?? data['${key}_url'] ?? '';
        if (v != null && (v as String).isNotEmpty) {
          if (v.startsWith('http://') || v.startsWith('https://')) {
            urls[key] = v;
          } else {
            final base = AppConstants.baseUrl;
            final cleanPath = v.startsWith('/') ? v : '/$v';
            urls[key] = '$base$cleanPath';
          }
        }
      }
      setState(() => _uploadedUrls = urls);

      // Pre-fill text fields
      _rcNumberCtrl.text  = data['rc_number']   ?? '';
      _dlNumberCtrl.text  = data['license_number'] ?? '';
      _aadhaarCtrl.text   = data['aadhaar_number'] ?? data['aadhar_number'] ?? '';
      if (data['registration_year'] != null)
        _rcRegYear    = int.tryParse('${data['registration_year']}')  ?? _rcRegYear;
      if (data['rc_expiry_year'] != null)
        _rcExpireYear = int.tryParse('${data['rc_expiry_year']}')     ?? _rcExpireYear;
      // FIX: backend returns 'license_expiry' as YYYY-MM-DD string, not 'dl_expiry_year'
      final licenseExpiry = data['license_expiry'] as String?;
      if (licenseExpiry != null && licenseExpiry.length >= 4)
        _dlExpireYear = int.tryParse(licenseExpiry.substring(0, 4)) ?? _dlExpireYear;
    }
    setState(() => _loading = false);
  }

  // ── Pick image ─────────────────────────────────────────
  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Choose Source', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _srcBtn(Icons.camera_alt_rounded, 'Camera',
              AppColors.primary, () => Navigator.pop(context, ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _srcBtn(Icons.photo_library_rounded, 'Gallery',
              AppColors.driverColor, () => Navigator.pop(context, ImageSource.gallery))),
          ]),
        ]),
      )),
    );
    if (source == null) return null;
    final picked = await _picker.pickImage(
      source: source, imageQuality: 80, maxWidth: 1200);
    return picked == null ? null : File(picked.path);
  }

  Widget _srcBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
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

  // ── Save all changes ───────────────────────────────────
  Future<void> _saveAll() async {
    setState(() { _saving = true; _error = ''; _success = ''; });

    // 1. Save text details
    await ApiService.saveDocumentDetails(
      driverId     : widget.driverId,
      rcNumber     : _rcNumberCtrl.text.trim().isEmpty ? null : _rcNumberCtrl.text.trim().toUpperCase(),
      rcRegYear    : _rcRegYear,
      rcExpireYear : _rcExpireYear,
      dlNumber     : _dlNumberCtrl.text.trim().isEmpty ? null : _dlNumberCtrl.text.trim().toUpperCase(),
      dlExpireYear : _dlExpireYear,
      aadhaarNumber: _aadhaarCtrl.text.trim().isEmpty ? null : _aadhaarCtrl.text.trim(),
    );

    // 2. Upload any new files
    final toUpload = _newFiles.entries
      .where((e) => e.value != null).toList();

    final List<String> failed = [];
    for (final entry in toUpload) {
      setState(() => _uploadingLabel = _label(entry.key));
      final res = await ApiService.uploadDocument(
        driverId: widget.driverId,
        docType : entry.key,
        file    : entry.value!,
      );
      if (res['success'] == true) {
        // Update local preview with new URL
        final url = res['data']?['url'] ?? res['data']?['${entry.key}_url'] ?? '';
        if ((url as String).isNotEmpty) {
          if (url.startsWith('http://') || url.startsWith('https://')) {
            _uploadedUrls[entry.key] = url;
          } else {
            final base = AppConstants.baseUrl;
            final cleanPath = url.startsWith('/') ? url : '/$url';
            _uploadedUrls[entry.key] = '$base$cleanPath';
          }
        }
        _newFiles[entry.key] = null;
      } else {
        failed.add(entry.key);
      }
    }

    setState(() => _saving = false);

    if (failed.isNotEmpty) {
      setState(() => _error =
        'Failed to upload: ${failed.map(_label).join(', ')}. Please retry.');
    } else {
      setState(() => _success = toUpload.isEmpty
        ? 'Details saved successfully ✅'
        : 'All documents saved successfully ✅');
      // Reload to get fresh URLs
      await _loadExisting();
    }
  }

  String _label(String key) {
    const m = {
      'profile_pic'   : 'Profile Photo',
      'rc_front'      : 'RC Front',
      'rc_back'       : 'RC Back',
      'dl_front'      : 'DL Front',
      'dl_back'       : 'DL Back',
      'aadhaar_front' : 'Aadhaar Front',
      'aadhaar_back'  : 'Aadhaar Back',
      'insurance'     : 'Insurance',
      'permit'        : 'Permit',
    };
    return m[key] ?? key;
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isRcReadOnly = _uploadedUrls['rc_front']?.isNotEmpty == true || _uploadedUrls['rc_back']?.isNotEmpty == true;
    final isDlReadOnly = _uploadedUrls['dl_front']?.isNotEmpty == true || _uploadedUrls['dl_back']?.isNotEmpty == true;
    final isAadhaarReadOnly = _uploadedUrls['aadhaar_front']?.isNotEmpty == true || _uploadedUrls['aadhaar_back']?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context)),
        title: Text('My Documents',
          style: GoogleFonts.sora(
            fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _saveAll,
              child: Text('Save All',
                style: GoogleFonts.sora(
                  color: AppColors.driverColor,
                  fontWeight: FontWeight.w700))),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [

          // ── Upload progress bar ────────────────────────
          if (_saving)
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uploading $_uploadingLabel...',
                    style: GoogleFonts.sora(
                      fontSize: 12, color: AppColors.driverColor,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    backgroundColor: AppColors.divider,
                    color: AppColors.driverColor,
                    minHeight: 5),
              ])),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [

                // ── Status messages ────────────────────────
                if (_error.isNotEmpty)
                  _msgBox(_error, AppColors.error, Icons.error_outline),
                if (_success.isNotEmpty)
                  _msgBox(_success, AppColors.success, Icons.check_circle_outline),

                const SizedBox(height: 4),

                // ══════════════════════════════════════════
                // 1. PROFILE PICTURE
                // ══════════════════════════════════════════
                _sectionCard(
                  icon: Icons.person_rounded,
                  color: AppColors.driverColor,
                  title: 'Profile Picture',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withOpacity(0.3))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 15),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'No helmet • No sunglasses • No cap\nClear face in good lighting',
                          style: GoogleFonts.sora(
                            fontSize: 11, color: AppColors.warning, height: 1.4))),
                      ]),
                    ),
                    _fullSlot('profile_pic', AppColors.driverColor, height: 140),
                  ]),
                ),

                const SizedBox(height: 14),

                // ══════════════════════════════════════════
                // 2. RC DETAILS
                // ══════════════════════════════════════════
                _sectionCard(
                  icon: Icons.directions_car_rounded,
                  color: AppColors.primary,
                  title: 'RC (Registration Certificate)',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _lbl('RC Number'),
                    _tf(_rcNumberCtrl, 'e.g. WB01AB1234',
                      Icons.pin_outlined,
                      caps: TextCapitalization.characters,
                      readOnly: isRcReadOnly),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _lbl('Registration Year'),
                        _yearDrop(_rcRegYear,
                          from: DateTime.now().year - 20,
                          to: DateTime.now().year,
                          onChanged: (v) => setState(() => _rcRegYear = v!),
                          color: AppColors.primary,
                          readOnly: isRcReadOnly),
                      ])),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _lbl('Expire Year'),
                        _yearDrop(_rcExpireYear,
                          from: DateTime.now().year,
                          to: DateTime.now().year + 15,
                          onChanged: (v) => setState(() => _rcExpireYear = v!),
                          color: AppColors.primary,
                          readOnly: isRcReadOnly),
                      ])),
                    ]),
                    const SizedBox(height: 10),
                    _lbl('Front & Back Photos'),
                    Row(children: [
                      Expanded(child: _slot('rc_front', AppColors.primary)),
                      const SizedBox(width: 10),
                      Expanded(child: _slot('rc_back', AppColors.primary)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 14),

                // ══════════════════════════════════════════
                // 3. DL DETAILS
                // ══════════════════════════════════════════
                _sectionCard(
                  icon: Icons.badge_rounded,
                  color: AppColors.driverColor,
                  title: 'Driving Licence (DL)',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _lbl('DL Number'),
                    _tf(_dlNumberCtrl, 'e.g. WB0120110012345',
                      Icons.credit_card_rounded,
                      caps: TextCapitalization.characters,
                      readOnly: isDlReadOnly),
                    const SizedBox(height: 10),
                    _lbl('Expire Year'),
                    _yearDrop(_dlExpireYear,
                      from: DateTime.now().year,
                      to: DateTime.now().year + 20,
                      onChanged: (v) => setState(() => _dlExpireYear = v!),
                      color: AppColors.driverColor,
                      readOnly: isDlReadOnly),
                    const SizedBox(height: 10),
                    _lbl('Front & Back Photos'),
                    Row(children: [
                      Expanded(child: _slot('dl_front', AppColors.driverColor)),
                      const SizedBox(width: 10),
                      Expanded(child: _slot('dl_back', AppColors.driverColor)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 14),

                // ══════════════════════════════════════════
                // 4. AADHAAR
                // ══════════════════════════════════════════
                _sectionCard(
                  icon: Icons.fingerprint_rounded,
                  color: AppColors.success,
                  title: 'Aadhaar Card',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _lbl('Aadhaar Number'),
                    _tf(_aadhaarCtrl, 'e.g. 1234 5678 9012',
                      Icons.numbers_rounded,
                      type: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12)],
                      readOnly: isAadhaarReadOnly),
                    const SizedBox(height: 10),
                    _lbl('Front & Back Photos'),
                    Row(children: [
                      Expanded(child: _slot('aadhaar_front', AppColors.success)),
                      const SizedBox(width: 10),
                      Expanded(child: _slot('aadhaar_back', AppColors.success)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 14),

                // ══════════════════════════════════════════
                // 5. INSURANCE
                // ══════════════════════════════════════════
                _sectionCard(
                  icon: Icons.security_rounded,
                  color: AppColors.warning,
                  title: 'Insurance Certificate',
                  badge: 'Required',
                  badgeColor: AppColors.error,
                  child: _fullSlot('insurance', AppColors.warning, height: 100),
                ),

                const SizedBox(height: 14),

                // ══════════════════════════════════════════
                // 6. PERMIT (optional)
                // ══════════════════════════════════════════
                _sectionCard(
                  icon: Icons.article_rounded,
                  color: AppColors.info,
                  title: 'Vehicle Permit',
                  badge: 'Optional',
                  badgeColor: AppColors.textSecondary,
                  child: _fullSlot('permit', AppColors.info, height: 100),
                ),

                const SizedBox(height: 30),

                // ── Save button ────────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.driverColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                      elevation: 0),
                    child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5)),
                          const SizedBox(width: 12),
                          Text('Saving...',
                            style: GoogleFonts.sora(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                        ])
                      : Text('Save All Changes',
                          style: GoogleFonts.sora(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ]),
    );
  }

  // ── Two-column image slot ──────────────────────────────
  Widget _slot(String key, Color color) {
    final newFile  = _newFiles[key];
    final existUrl = _uploadedUrls[key] ?? '';
    final hasImage = newFile != null || existUrl.isNotEmpty;
    final isReadOnly = existUrl.isNotEmpty;

    return GestureDetector(
      onTap: _saving || isReadOnly ? null : () async {
        final f = await _pickImage();
        if (f != null) setState(() => _newFiles[key] = f);
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: hasImage ? Colors.transparent : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
              ? AppColors.success.withOpacity(0.5)
              : color.withOpacity(0.3),
            width: 1.5)),
        child: hasImage
          ? Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: newFile != null
                  ? Image.file(newFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover)
                  : Image.network(existUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: color.withOpacity(0.1),
                        child: Icon(Icons.broken_image_rounded,
                          color: color, size: 30)))),
              // Re-upload button (ONLY show if NOT read-only)
              if (!isReadOnly)
                Positioned(top: 4, right: 4,
                  child: GestureDetector(
                    onTap: _saving ? null : () async {
                      final f = await _pickImage();
                      if (f != null) setState(() => _newFiles[key] = f);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 13)))),
              // Uploaded indicator
              if (existUrl.isNotEmpty && newFile == null)
                Positioned(bottom: 4, right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(6)),
                    child: Text('✓ Uploaded',
                      style: GoogleFonts.sora(
                        fontSize: 9, color: Colors.white,
                        fontWeight: FontWeight.w700)))),
              // Label bar
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(11))),
                  child: Text(_label(key),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(
                      fontSize: 9, color: Colors.white,
                      fontWeight: FontWeight.w600)))),
            ])
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Icon(Icons.cloud_upload_rounded,
                color: color.withOpacity(0.5), size: 24),
              const SizedBox(height: 4),
              Text(_label(key),
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8))),
              Text('Tap to upload',
                style: GoogleFonts.sora(
                  fontSize: 9, color: AppColors.textHint)),
            ]),
      ),
    );
  }

  // ── Full-width image slot ──────────────────────────────
  Widget _fullSlot(String key, Color color, {double height = 100}) {
    final newFile  = _newFiles[key];
    final existUrl = _uploadedUrls[key] ?? '';
    final hasImage = newFile != null || existUrl.isNotEmpty;
    final isReadOnly = existUrl.isNotEmpty;

    return GestureDetector(
      onTap: _saving || isReadOnly ? null : () async {
        final f = await _pickImage();
        if (f != null) setState(() => _newFiles[key] = f);
      },
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasImage ? Colors.transparent : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
              ? AppColors.success.withOpacity(0.5)
              : color.withOpacity(0.3),
            width: 1.5)),
        child: hasImage
          ? Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: newFile != null
                  ? Image.file(newFile,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover)
                  : Image.network(existUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: color.withOpacity(0.1),
                        child: Icon(Icons.broken_image_rounded,
                          color: color, size: 36)))),
              if (!isReadOnly)
                Positioned(top: 6, right: 6,
                  child: GestureDetector(
                    onTap: _saving ? null : () async {
                      final f = await _pickImage();
                      if (f != null) setState(() => _newFiles[key] = f);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16)))),
              if (existUrl.isNotEmpty && newFile == null)
                Positioned(bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8)),
                    child: Text('✓ Uploaded',
                      style: GoogleFonts.sora(
                        fontSize: 10, color: Colors.white,
                        fontWeight: FontWeight.w700)))),
            ])
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Icon(Icons.cloud_upload_rounded,
                color: color.withOpacity(0.5), size: 30),
              const SizedBox(height: 6),
              Text(_label(key),
                style: GoogleFonts.sora(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8))),
              Text('Tap to upload',
                style: GoogleFonts.sora(
                  fontSize: 11, color: AppColors.textHint)),
            ]),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   badge,
    required Color    badgeColor,
    required Widget   child,
  }) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider, width: 1.5),
      boxShadow: [BoxShadow(
        color: AppColors.shadow, blurRadius: 6,
        offset: const Offset(0, 2))]),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 10),
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
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: GoogleFonts.sora(
      fontSize: 12, fontWeight: FontWeight.w600,
      color: AppColors.textPrimary)));

  Widget _tf(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextCapitalization caps       = TextCapitalization.none,
    TextInputType type            = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool readOnly                 = false,
  }) => TextField(
    controller: ctrl,
    keyboardType: type,
    textCapitalization: caps,
    inputFormatters: formatters,
    enabled: !_saving && !readOnly,
    style: GoogleFonts.sora(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(
        color: AppColors.textHint, fontSize: 13),
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
        borderSide: const BorderSide(
          color: AppColors.driverColor, width: 2)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 12)));

  Widget _yearDrop(
    int value, {
    required int from,
    required int to,
    required void Function(int?) onChanged,
    required Color color,
    bool readOnly = false,
  }) {
    final years = List.generate(
      to - from + 1, (i) => from + i).reversed.toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider, width: 1.5),
        borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          style: GoogleFonts.sora(
            fontSize: 13, color: AppColors.textPrimary),
          items: years.map((y) => DropdownMenuItem(
            value: y, child: Text('$y'))).toList(),
          onChanged: _saving || readOnly ? null : onChanged)));
  }

  Widget _msgBox(String msg, Color color, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
        style: GoogleFonts.sora(
          fontSize: 12, color: color))),
    ]));

  @override
  void dispose() {
    _rcNumberCtrl.dispose();
    _dlNumberCtrl.dispose();
    _aadhaarCtrl.dispose();
    super.dispose();
  }
}
