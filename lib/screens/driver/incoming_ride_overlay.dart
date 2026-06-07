import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';

class IncomingRideOverlay extends StatefulWidget {
  const IncomingRideOverlay({super.key});

  @override
  State<IncomingRideOverlay> createState() => _IncomingRideOverlayState();
}

class _IncomingRideOverlayState extends State<IncomingRideOverlay> {
  static const _channel = MethodChannel('com.kride.app/native_bridge');
  
  Map<String, dynamic>? _tripData;
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    
    // Listen for data from the main application isolate
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _tripData = Map<String, dynamic>.from(event);
          // Set countdown duration if available in payload, default to 30
          _secondsLeft = _tripData?['secondsLeft'] ?? 30;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        FlutterOverlayWindow.closeOverlay();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_tripData == null) return;
    
    // Send action back to main isolate
    await FlutterOverlayWindow.shareData({
      'action': 'accept',
      'tripId': _tripData!['id'],
    });

    // Bring main app to foreground
    try {
      await _channel.invokeMethod('bringToForeground');
    } catch (e) {
      debugPrint("Failed to bring app to foreground: $e");
    }

    // Close overlay
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _handleDecline() async {
    if (_tripData != null) {
      await FlutterOverlayWindow.shareData({
        'action': 'decline',
        'tripId': _tripData!['id'],
      });
    }
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    if (_tripData == null) {
      // Show loading or fallback layout if data has not arrived yet
      return const SizedBox.shrink();
    }

    final double fare = (_tripData!['fare'] ?? 0).toDouble();
    final String pickup = _tripData!['pickup'] ?? 'Pickup location';
    final String drop = _tripData!['drop'] ?? 'Drop location';
    final String distance = _tripData!['distance'] ?? '0';
    final double pickupDistanceKm = (_tripData!['pickupDistanceKm'] ?? 0.0).toDouble();
    final String vehicle = (_tripData!['vehicle'] ?? 'cab').toString().toUpperCase();
    final String payment = _tripData!['payment'] ?? 'Cash';

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const EdgeInsets.symmetric(vertical: 4),
              ),
            ],
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Status Row
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'NEW ${vehicle} REQUEST',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fare & Details Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${AppConstants.currency}${fare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Earning via $payment',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${pickupDistanceKm.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Trip: $distance km',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),

                    // Pickup & Drop visual flow
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dots / Icons Column
                        Column(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: AppColors.success,
                              size: 14,
                            ),
                            Container(
                              width: 2,
                              height: 32,
                              color: AppColors.divider,
                            ),
                            const Icon(
                              Icons.location_on,
                              color: AppColors.error,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Addresses
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickup,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                drop,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons Row
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _handleDecline,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Accept Ride',
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
            ],
          ),
        ),
      ),
    );
  }
}
