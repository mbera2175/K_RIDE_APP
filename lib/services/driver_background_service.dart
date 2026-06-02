import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'auth_service.dart';
import 'api_service.dart';

// Initialize the background service configuration
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // We manually start/stop it when toggling Online
      isForegroundMode: true,
      notificationChannelId: 'kride_driver_channel',
      initialNotificationTitle: 'KRide Driver',
      initialNotificationContent: 'You are online and ready to receive rides.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Dart side is initialized in the isolate
  DartPluginRegistrant.ensureInitialized();
  
  // Initialize SharedPreferences inside this isolate
  await AuthService.init();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Perform periodic pings every 30 seconds
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    // Re-read SharedPreferences session inside loop to check if still logged in
    await AuthService.init();
    
    if (AuthService.token.isEmpty || AuthService.role != 'driver') {
      service.stopSelf();
      timer.cancel();
      return;
    }

    try {
      final res = await ApiService.sendHeartbeat();
      if (res['success'] == true) {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "KRide Driver (Online)",
            content: "Heartbeat active. Ready for new rides.",
          );
        }
      } else {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "KRide Driver (Connection Error)",
            content: "Attempting to reconnect...",
          );
        }
      }
    } catch (e) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "KRide Driver (Offline)",
          content: "Failed to send heartbeat.",
        );
      }
    }
  });
}
